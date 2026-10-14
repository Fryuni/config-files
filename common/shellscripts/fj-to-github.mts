#!/usr/bin/env bun

import { $ } from "bun";
import { homedir } from "node:os";
import { join } from "node:path";

type Repository = {
  private: boolean;
  permissions?: { admin?: boolean };
};

type PushMirror = {
  remote_address: string;
  public_key?: string;
};

// Home Manager installs each script as a separate store file, so keep this
// credential reader local instead of importing a sibling module.
async function forgejoApi(host: string) {
  // Let fj validate the login and refresh an OAuth token before reading it.
  await $`fj -H ${host} whoami`.quiet();
  const keys = await Bun.file(
    join(process.env.XDG_DATA_HOME || join(homedir(), ".local/share"), "forgejo-cli/keys.json"),
  ).json();
  const apiHost = keys.aliases?.[host] ?? host;
  const token = keys.hosts?.[apiHost]?.token;
  if (!token) throw new Error(`No fj authentication found for ${host}.`);
  const version = (await $`fj version`.quiet().text()).trim().replace(/^fj v/, "");

  return async function request<T>(path: string, body?: object): Promise<T> {
    const response = await fetch(`https://${apiHost}/api/v1/${path}`, {
      method: body ? "POST" : "GET",
      redirect: "error",
      headers: {
        Authorization: `token ${token}`,
        "Content-Type": "application/json",
        "User-Agent": `forgejo-cli/${version} (https://codeberg.org/forgejo-contrib/forgejo-cli/)`,
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    if (!response.ok) {
      throw new Error(`Forgejo ${path} failed (HTTP ${response.status}).`);
    }
    const text = await response.text();
    return text ? JSON.parse(text) as T : undefined as T;
  };
}

async function githubRepo(ref: string): Promise<Repository | null> {
  const result = await $`gh api --hostname github.com repos/${ref}`.quiet().nothrow();
  if (result.exitCode === 0) return result.json();
  if (/\(HTTP 404\)/.test(result.stderr.toString())) return null;
  throw new Error(result.stderr.toString().trim() || `Cannot access GitHub repository ${ref}.`);
}

async function main() {
  const args = Bun.argv.slice(2);
  const usage = "Usage: fj-to-github <host>/<owner>/<name> <owner>/<name>";
  if (args.length === 1 && ["--help", "-h"].includes(args[0])) {
    console.log(`${usage}\n\nCreate an SSH push mirror with a writable GitHub deploy key. Requires fj and gh.`);
    return;
  }
  const [forgejoRef, githubRef] = args;
  if (args.length !== 2
    || !/^[\w.-]+(?::\d+)?\/[\w-]+\/[\w.-]+$/.test(forgejoRef)
    || !/^[\w-]+\/[\w.-]+$/.test(githubRef)
    || [forgejoRef, githubRef].some(ref => ref.split("/").some(part => [".", ".."].includes(part)))) {
    throw new Error(usage);
  }

  const [host, owner, name] = forgejoRef.split("/");
  const api = await forgejoApi(host);
  const repoPath = `repos/${owner}/${name}`;
  const source = await api<Repository>(repoPath);
  if (source.permissions?.admin !== true) {
    throw new Error(`Admin access to ${forgejoRef} is required.`);
  }

  // Verify authentication separately: an expired login must not look like a
  // missing repository and trigger creation.
  await $`gh api --hostname github.com user`.quiet();
  let target = await githubRepo(githubRef);
  if (!target) {
    await $`gh repo create github.com/${githubRef} ${source.private ? "--private" : "--public"}`;
    target = await githubRepo(githubRef);
  }
  if (target?.permissions?.admin !== true) {
    throw new Error(`Admin access to GitHub repository ${githubRef} is required.`);
  }
  if (source.private && target.private !== true) {
    throw new Error(`Cannot mirror private repository ${forgejoRef} to public GitHub repository ${githubRef}. Make the GitHub repository private before retrying.`);
  }

  const remoteAddress = `git@github.com:${githubRef}.git`;
  let mirror: PushMirror | undefined;
  // Forgejo paginates mirrors; find an existing one so a partial setup can be
  // retried without generating another key or duplicate push target.
  for (let page = 1; ; page++) {
    const mirrors = await api<PushMirror[]>(`${repoPath}/push_mirrors?limit=50&page=${page}`);
    mirror = mirrors.find(item =>
      [remoteAddress, `ssh://git@github.com/${githubRef}.git`]
        .some(address => address.toLowerCase() === item.remote_address.toLowerCase()),
    );
    if (mirror || mirrors.length === 0) break;
  }
  if (!mirror) {
    // fj add-push-target currently omits the required interval. Use the API
    // with fj's credentials to enable both scheduled and on-commit pushes.
    mirror = await api<PushMirror>(`${repoPath}/push_mirrors`, {
      remote_address: remoteAddress,
      use_ssh: true,
      interval: "8h",
      sync_on_commit: true,
    });
  }
  const publicKey = mirror.public_key?.trim();
  if (!publicKey) {
    throw new Error(`The push mirror to ${githubRef} has no generated SSH key. Remove that push target and rerun.`);
  }

  const pages = await $`gh api --hostname github.com repos/${githubRef}/keys --paginate --slurp`.quiet().json();
  const keyMaterial = (key: string) => key.trim().split(/\s+/).slice(0, 2).join(" ");
  const existingKey = pages.flat().find((key: { key: string }) => keyMaterial(key.key) === keyMaterial(publicKey));
  if (existingKey?.read_only === true) {
    throw new Error(`The mirror's GitHub deploy key is read-only. Replace it with a writable deploy key and rerun.`);
  }
  if (!existingKey) {
    const payload = Buffer.from(JSON.stringify({
      title: `Forgejo push mirror: ${forgejoRef}`,
      key: publicKey,
      read_only: false,
    }));
    await $`gh api --hostname github.com --method POST repos/${githubRef}/keys --input - <${payload}`.quiet();
  }

  // Sync only after GitHub accepts the key. This endpoint queues the push.
  await api(`${repoPath}/push_mirrors-sync`, {});
  console.log(`Push mirror configured: ${forgejoRef} -> github.com/${githubRef}; initial sync queued.`);
}

try {
  await main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}
