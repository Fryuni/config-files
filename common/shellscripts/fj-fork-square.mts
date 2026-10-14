#!/usr/bin/env bun

import { $ } from "bun";
import { homedir } from "node:os";
import { join } from "node:path";

type Repository = {
  id: number;
  name: string;
  full_name: string;
  fork: boolean;
  private: boolean;
  mirror?: boolean;
  original_url?: string;
  parent?: { id: number };
  source?: { id: number };
  owner: { login: string };
};

// Scripts are installed as separate Nix store files, without sibling imports.
async function forgejoApi(host: string) {
  await $`fj -H ${host} whoami`.quiet();
  const keys = await Bun.file(
    join(process.env.XDG_DATA_HOME || join(homedir(), ".local/share"), "forgejo-cli/keys.json"),
  ).json();
  const apiHost = keys.aliases?.[host] ?? host;
  const token = keys.hosts?.[apiHost]?.token;
  if (!token) throw new Error(`No fj authentication found for ${host}.`);
  const version = (await $`fj version`.quiet().text()).trim().replace(/^fj v/, "");

  return async function request<T>(path: string, allowMissing = false): Promise<T | null> {
    const response = await fetch(`https://${apiHost}/api/v1/${path}`, {
      redirect: "error",
      headers: {
        Authorization: `token ${token}`,
        "User-Agent": `forgejo-cli/${version} (https://codeberg.org/forgejo-contrib/forgejo-cli/)`,
      },
    });
    if (allowMissing && response.status === 404) return null;
    if (!response.ok) throw new Error(`Forgejo ${path} failed (HTTP ${response.status}).`);
    return await response.json() as T;
  };
}

async function main() {
  const args = Bun.argv.slice(2);
  const usage = "Usage: fj-fork-square <github-owner>/<repo> [forgejo-host]";
  if (args.length === 1 && ["--help", "-h"].includes(args[0])) {
    console.log(`${usage}\n\nMirror upstream, fork on both hosts, and push-mirror your Forgejo fork to GitHub.\nForgejo host defaults to git.fryuni.dev. Requires fj, gh, fj-from-github and fj-to-github.`);
    return;
  }
  const [originalRef, host = "git.fryuni.dev"] = args;
  if (args.length < 1 || args.length > 2
    || !/^[\w-]+\/[\w.-]+$/.test(originalRef)
    || !/^[\w.-]+(?::\d+)?$/.test(host)
    || [".", ".."].includes(host)
    || originalRef.split("/").some(part => [".", ".."].includes(part))) {
    throw new Error(usage);
  }

  const original: Repository = await $`gh api --hostname github.com repos/${originalRef}`.quiet().json();
  const githubUser: { login: string } = await $`gh api --hostname github.com user`.quiet().json();
  if (original.owner.login.toLowerCase() === githubUser.login.toLowerCase()) {
    throw new Error(`Cannot create a personal GitHub fork of your own repository ${original.full_name}.`);
  }

  const api = await forgejoApi(host);
  const forgejoUser = await api<{ login: string }>("user");
  if (!forgejoUser) throw new Error(`Cannot resolve the authenticated Forgejo user on ${host}.`);
  const mirrorRef = `mirror/${original.name}`;
  let mirror = await api<Repository>(`repos/${mirrorRef}`, true);
  if (!mirror) {
    await $`fj-from-github ${original.full_name} ${host}`;
    mirror = await api<Repository>(`repos/${mirrorRef}`);
  }
  const normalizeGithubUrl = (url: string) => url.replace(/\/$/, "").replace(/\.git$/, "").toLowerCase();
  if (!mirror?.mirror
    || normalizeGithubUrl(mirror.original_url ?? "") !== normalizeGithubUrl(`https://github.com/${original.full_name}`)) {
    throw new Error(`${host}/${mirrorRef} is not a pull mirror of ${original.full_name}.`);
  }
  if (original.private && mirror.private !== true) {
    throw new Error(`Private upstream ${original.full_name} has a public Forgejo mirror at ${host}/${mirrorRef}. Make the mirror private before retrying.`);
  }

  const forgejoForkRef = `${forgejoUser.login}/${original.name}`;
  let forgejoFork = await api<Repository>(`repos/${forgejoForkRef}`, true);
  if (!forgejoFork) {
    await $`fj -H ${host} repo fork ${mirrorRef}`;
    forgejoFork = await api<Repository>(`repos/${forgejoForkRef}`);
  }
  if (!forgejoFork?.fork || forgejoFork.parent?.id !== mirror.id) {
    throw new Error(`${host}/${forgejoForkRef} is not a fork of ${mirrorRef}.`);
  }

  // Search owned forks by network identity, rather than assuming the fork
  // kept upstream's name. REST list results omit parent/source information.
  const pages: Repository[][] = await $`gh api --hostname github.com --method GET user/repos -f affiliation=owner -f per_page=100 --paginate --slurp`.quiet().json();
  const networkId = original.source?.id ?? original.id;
  let githubFork: Repository | undefined;
  for (const candidate of pages.flat().filter(repo => repo.fork)) {
    const details: Repository = await $`gh api --hostname github.com repos/${candidate.full_name}`.quiet().json();
    if ((details.source?.id ?? details.parent?.id) === networkId) {
      githubFork = details;
      break;
    }
  }
  if (!githubFork) {
    githubFork = await $`gh api --hostname github.com --method POST repos/${original.full_name}/forks`.quiet().json();
  }
  if (!githubFork?.full_name) throw new Error("GitHub did not return the fork's repository name.");

  // Fork creation is asynchronous. Wait for the repository API to see it
  // before invoking fj-to-github, which would otherwise try to create it.
  for (let attempt = 0; ; attempt++) {
    const result = await $`gh api --hostname github.com repos/${githubFork.full_name}`.quiet().nothrow();
    if (result.exitCode === 0) break;
    if (!/\(HTTP 404\)/.test(result.stderr.toString())) {
      throw new Error(result.stderr.toString().trim() || "Cannot access the GitHub fork.");
    }
    if (attempt >= 59) throw new Error("GitHub fork did not become available within five minutes. Rerun to resume.");
    await Bun.sleep(5000);
  }

  await $`fj-to-github ${`${host}/${forgejoFork.full_name}`} ${githubFork.full_name}`;
  console.log(`Fork square ready: work in https://${host}/${forgejoFork.full_name}; contribute from https://github.com/${githubFork.full_name}.`);
}

try {
  await main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}
