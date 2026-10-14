import { expect, test } from "bun:test";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

// Exercise the actual scripts in subprocesses, with isolated fj credentials,
// fake CLIs, and a fetch preload. No real repositories or credentials are used.
const cli = String.raw`#!${process.execPath}
import { readFileSync, writeFileSync } from "node:fs";
import { basename } from "node:path";
const command = basename(Bun.argv[1]);
const args = Bun.argv.slice(2);
const state = JSON.parse(readFileSync(process.env.FJ_TEST_STATE, "utf8"));
const input = args.includes("--input") ? await Bun.stdin.text() : "";
state.events.push({ command, args, ...(input ? { body: JSON.parse(input) } : {}) });
function finish(value, status = 0) {
  writeFileSync(process.env.FJ_TEST_STATE, JSON.stringify(state));
  if (status) console.error(value);
  else if (value !== undefined) console.log(typeof value === "string" ? value : JSON.stringify(value));
  process.exit(status);
}
if (command === "fj") {
  if (args.includes("whoami")) finish("signed in", state.fjAuthFails ? 1 : 0);
  if (args.includes("version")) finish("fj v0.6.0");
  if (args.includes("fork")) { state.forgejoFork = state.newForgejoFork; finish("Forked"); }
  if (args.includes("migrate")) finish("Migrated");
}
if (command === "fj-from-github") { state.mirror = state.newMirror; finish(); }
if (command === "fj-to-github") finish();
if (command === "gh") {
  if (args[0] === "auth") finish("fake-github-token");
  if (args[0] === "repo" && args[1] === "view") finish(state.upstream);
  if (args[0] === "repo" && args[1] === "create") {
    state.githubRepo = { private: args.includes("--private"), permissions: { admin: !state.createdNonAdmin } }; finish("Created");
  }
  const endpoint = args.find(arg => /^(user$|user\/|repos\/)/.test(arg));
  if (endpoint === "user") finish({ login: "github-user" }, state.ghAuthFails ? 1 : 0);
  if (endpoint === "user/repos") finish([state.githubForks]);
  if (endpoint?.endsWith("/forks")) { state.githubFork = state.newGithubFork; finish(state.githubFork); }
  if (endpoint?.endsWith("/keys")) {
    if (args.includes("POST")) {
      if (state.keyFails) finish("Deploy key rejected (HTTP 403)", 1);
      state.keys.push(input ? JSON.parse(input) : {}); finish({});
    }
    finish([state.keys]);
  }
  if (endpoint === "repos/upstream/project") finish(state.upstream);
  if (endpoint === "repos/github-user/renamed") finish(state.githubFork);
  if (endpoint === "repos/github-user/project" && state.githubFork) {
    if (state.forkNotVisible > 0) { state.forkNotVisible--; finish("Not Found (HTTP 404)", 1); }
    finish(state.githubFork);
  }
  if (state.ghRepoError) finish("GitHub API failed (HTTP " + state.ghRepoError + ")", 1);
  if (!state.githubRepo) finish("Not Found (HTTP 404)", 1);
  finish(state.githubRepo);
}
finish("Unexpected command: " + command + " " + args.join(" "), 1);
`;

const preload = String.raw`
import { readFileSync, writeFileSync } from "node:fs";
Bun.sleep = async () => {};
globalThis.fetch = async (url, options = {}) => {
  const state = JSON.parse(readFileSync(process.env.FJ_TEST_STATE, "utf8"));
  if (options.headers.Authorization !== "token fake-forgejo-token") throw new Error("Wrong fj credential");
  const path = new URL(url).pathname.replace("/api/v1/", "");
  state.events.push({ api: path, method: options.method ?? "GET", ...(options.body ? { body: JSON.parse(options.body) } : {}) });
  let value;
  let status = 200;
  if (path === "user") value = { login: "forgejo-user" };
  else if (path === "repos/owner/project") { value = state.forgejoRepo; status = state.forgejoStatus ?? 200; }
  else if (path === "repos/mirror/project") { value = state.mirror; status = value ? 200 : 404; }
  else if (path === "repos/forgejo-user/project") { value = state.forgejoFork; status = value ? 200 : 404; }
  else if (path.endsWith("/push_mirrors-sync")) value = undefined;
  else if (path.endsWith("/push_mirrors")) {
    if (options.method === "POST") {
      value = { remote_address: "git@github.com:github-user/project.git", public_key: "ssh-ed25519 AAAATEST mirror" };
      state.mirrors.push(value);
    } else value = new URL(url).searchParams.get("page") === "1" ? state.mirrors : [];
  } else throw new Error("Unexpected endpoint: " + path);
  writeFileSync(process.env.FJ_TEST_STATE, JSON.stringify(state));
  return new Response(value === undefined ? null : JSON.stringify(value), { status });
};
`;

const defaults = () => ({
  events: [] as any[],
  forgejoRepo: { private: false, permissions: { admin: true } },
  githubRepo: { private: false, permissions: { admin: true } },
  mirrors: [] as any[],
  keys: [] as any[],
  upstream: { id: 1, name: "project", full_name: "upstream/project", owner: { login: "upstream" }, private: false, isPrivate: false, url: "https://github.com/upstream/project" },
  newMirror: { id: 2, mirror: true, private: false, original_url: "https://github.com/upstream/project.git" },
  newForgejoFork: { id: 3, full_name: "forgejo-user/project", fork: true, private: false, parent: { id: 2 } },
  newGithubFork: { id: 4, full_name: "github-user/project", fork: true, private: false, source: { id: 1 } },
  githubForks: [] as any[],
});

async function run(script: string, changes: object = {}, args?: string[]) {
  const dir = await mkdtemp(join(tmpdir(), "fj-github-test-"));
  try {
    const bin = join(dir, "bin");
    const data = join(dir, "data");
    await mkdir(bin);
    await mkdir(join(data, "forgejo-cli"), { recursive: true });
    await writeFile(join(data, "forgejo-cli/keys.json"), JSON.stringify({ hosts: { "forgejo.test": { type: "Application", token: "fake-forgejo-token" } } }));
    await writeFile(join(dir, "state.json"), JSON.stringify({ ...defaults(), ...changes }));
    await writeFile(join(dir, "preload.mjs"), preload);
    for (const command of ["fj", "gh", "fj-from-github", "fj-to-github"]) {
      await writeFile(join(bin, command), cli, { mode: 0o755 });
    }
    const proc = Bun.spawn([
      process.execPath, "--preload", join(dir, "preload.mjs"),
      new URL(`../${script}.mts`, import.meta.url).pathname,
      ...(args ?? (script === "fj-to-github"
        ? ["forgejo.test/owner/project", "github-user/project"]
        : script === "fj-from-github" ? ["upstream/project", "forgejo.test"] : ["upstream/project", "forgejo.test"])),
    ], {
      env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, XDG_DATA_HOME: data, FJ_TEST_STATE: join(dir, "state.json") },
      stdout: "pipe", stderr: "pipe",
    });
    const [stdout, stderr, exitCode] = await Promise.all([
      new Response(proc.stdout).text(), new Response(proc.stderr).text(), proc.exited,
    ]);
    const state = JSON.parse(await readFile(join(dir, "state.json"), "utf8"));
    return { exitCode, stdout, stderr, state, events: state.events as any[] };
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

const mutations = (events: any[]) => events.filter(event => event.method === "POST"
  || event.command === "fj-from-github" || event.command === "fj-to-github"
  || event.args?.includes("create") || event.args?.includes("fork") || event.args?.includes("POST"));

test("creates a scheduled/on-commit SSH mirror, writable key, then queues the first push", async () => {
  const result = await run("fj-to-github");
  expect(result.exitCode).toBe(0);
  const writes = mutations(result.events);
  expect(writes.map(event => event.api ?? event.command)).toEqual(["repos/owner/project/push_mirrors", "gh", "repos/owner/project/push_mirrors-sync"]);
  expect(writes[0].body).toEqual({ remote_address: "git@github.com:github-user/project.git", interval: "8h", sync_on_commit: true, use_ssh: true });
  expect(writes[1].body.read_only).toBe(false);
  expect(result.stdout).not.toContain("fake-forgejo-token");
});

for (const [label, changes] of [
  ["missing Forgejo repo", { forgejoStatus: 404 }],
  ["Forgejo authentication failure", { fjAuthFails: true }],
  ["Forgejo non-admin", { forgejoRepo: { permissions: { admin: false } } }],
  ["GitHub non-admin", { githubRepo: { permissions: { admin: false } } }],
  ["GitHub authentication failure", { ghAuthFails: true }],
  ["GitHub API forbidden", { ghRepoError: 403 }],
  ["GitHub API server error", { ghRepoError: 500 }],
] as const) {
  test(`aborts without mutations on ${label}`, async () => {
    const result = await run("fj-to-github", changes);
    expect(result.exitCode).toBe(1);
    expect(mutations(result.events)).toEqual([]);
  });
}

test("creates a missing GitHub repo with the source's privacy and checks admin access", async () => {
  const result = await run("fj-to-github", { githubRepo: null, forgejoRepo: { private: true, permissions: { admin: true } } });
  expect(result.exitCode).toBe(0);
  expect(mutations(result.events)[0].args).toEqual(["repo", "create", "github.com/github-user/project", "--private"]);
  const denied = await run("fj-to-github", { githubRepo: null, createdNonAdmin: true });
  expect(denied.exitCode).toBe(1);
  expect(mutations(denied.events)).toHaveLength(1);
});

test("rejects a public GitHub target for a private source before configuring or reusing mirrors", async () => {
  for (const mirrors of [[], [{ remote_address: "git@github.com:github-user/project.git", public_key: "ssh-ed25519 AAAATEST forgejo" }]]) {
    const result = await run("fj-to-github", {
      forgejoRepo: { private: true, permissions: { admin: true } },
      mirrors,
      keys: [{ key: "ssh-ed25519 AAAATEST", read_only: false }],
    });
    expect(result.exitCode).toBe(1);
    expect(result.stderr).toContain("Make the GitHub repository private before retrying");
    expect(mutations(result.events)).toEqual([]);
  }
});

test("allows a private source to mirror to an existing private GitHub target", async () => {
  const result = await run("fj-to-github", {
    forgejoRepo: { private: true, permissions: { admin: true } },
    githubRepo: { private: true, permissions: { admin: true } },
  });
  expect(result.exitCode).toBe(0);
  expect(mutations(result.events).at(-1).api).toBe("repos/owner/project/push_mirrors-sync");
});

test("reuses a mirror and deploy key, comparing key material without comments", async () => {
  const result = await run("fj-to-github", {
    mirrors: [{ remote_address: "ssh://git@github.com/github-user/project.git", public_key: "ssh-ed25519 AAAATEST forgejo" }],
    keys: [{ key: "ssh-ed25519 AAAATEST github", read_only: false }],
  });
  expect(result.exitCode).toBe(0);
  expect(mutations(result.events).map(event => event.api)).toEqual(["repos/owner/project/push_mirrors-sync"]);
});

test("aborts on an existing read-only key or a mirror without an SSH key", async () => {
  for (const public_key of ["ssh-ed25519 AAAATEST forgejo", undefined]) {
    const result = await run("fj-to-github", {
      mirrors: [{ remote_address: "git@github.com:github-user/project.git", public_key }],
      keys: [{ key: "ssh-ed25519 AAAATEST", read_only: true }],
    });
    expect(result.exitCode).toBe(1);
    expect(mutations(result.events)).toEqual([]);
  }
});

test("does not queue a push if GitHub rejects the deploy key", async () => {
  const result = await run("fj-to-github", { keyFails: true });
  expect(result.exitCode).toBe(1);
  expect(result.events.some(event => event.api?.endsWith("push_mirrors-sync"))).toBe(false);
});

test("builds the fork square in order and uses each authenticated user's identity", async () => {
  const result = await run("fj-fork-square");
  expect(result.exitCode).toBe(0);
  const writes = mutations(result.events);
  expect(writes.map(event => event.command)).toEqual(["fj-from-github", "fj", "gh", "fj-to-github"]);
  expect(writes[0].args).toEqual(["upstream/project", "forgejo.test"]);
  expect(writes[1].args).toEqual(["-H", "forgejo.test", "repo", "fork", "mirror/project"]);
  expect(writes[3].args).toEqual(["forgejo.test/forgejo-user/project", "github-user/project"]);
});

test("resumes an existing square and locates a renamed GitHub fork", async () => {
  const data = defaults();
  const result = await run("fj-fork-square", {
    mirror: data.newMirror, forgejoFork: data.newForgejoFork,
    githubForks: [{ full_name: "github-user/renamed", fork: true }],
    githubFork: { ...data.newGithubFork, full_name: "github-user/renamed" },
  });
  expect(result.exitCode).toBe(0);
  expect(mutations(result.events)).toHaveLength(1);
  expect(mutations(result.events)[0].args[1]).toBe("github-user/renamed");
});

test("rejects an existing public pull mirror for a private GitHub upstream before forking", async () => {
  const data = defaults();
  const result = await run("fj-fork-square", {
    upstream: { ...data.upstream, private: true, isPrivate: true },
    mirror: data.newMirror,
  });
  expect(result.exitCode).toBe(1);
  expect(result.stderr).toContain("Make the mirror private before retrying");
  expect(mutations(result.events)).toEqual([]);
});

test("resumes a private fork square with a private pull mirror", async () => {
  const data = defaults();
  const result = await run("fj-fork-square", {
    upstream: { ...data.upstream, private: true, isPrivate: true },
    mirror: { ...data.newMirror, private: true },
    forgejoFork: { ...data.newForgejoFork, private: true },
    githubForks: [{ ...data.newGithubFork, private: true }],
    githubFork: { ...data.newGithubFork, private: true },
  });
  expect(result.exitCode).toBe(0);
  expect(mutations(result.events)).toHaveLength(1);
  expect(mutations(result.events)[0].command).toBe("fj-to-github");
});

test("waits for an asynchronous GitHub fork before configuring the push mirror", async () => {
  const result = await run("fj-fork-square", { forkNotVisible: 2 });
  expect(result.exitCode).toBe(0);
  expect(result.events.filter(event => event.args?.includes("repos/github-user/project"))).toHaveLength(3);
  expect(result.events.at(-1).command).toBe("fj-to-github");
});

test("rejects collisions in the mirror namespace and in the Forgejo user's namespace", async () => {
  for (const changes of [
    { mirror: { ...defaults().newMirror, original_url: "https://github.com/other/project" } },
    { mirror: defaults().newMirror, forgejoFork: { ...defaults().newForgejoFork, parent: { id: 999 } } },
  ]) {
    const result = await run("fj-fork-square", changes);
    expect(result.exitCode).toBe(1);
    expect(mutations(result.events)).toEqual([]);
  }
});

test("rejects invalid references before invoking any CLI", async () => {
  for (const [script, args] of [
    ["fj-to-github", ["https://forgejo.test/owner/project", "github-user/project"]],
    ["fj-to-github", ["forgejo.test/owner/..", "github-user/project"]],
    ["fj-fork-square", ["upstream/project", "https://forgejo.test"]],
  ] as const) {
    const result = await run(script, {}, [...args]);
    expect(result.exitCode).toBe(1);
    expect(result.events).toEqual([]);
  }
});

test("keeps private GitHub upstreams private when creating the pull mirror", async () => {
  const result = await run("fj-from-github", { upstream: { ...defaults().upstream, isPrivate: true } });
  expect(result.exitCode).toBe(0);
  expect(result.events.find(event => event.command === "fj").args).toContain("--private");
});
