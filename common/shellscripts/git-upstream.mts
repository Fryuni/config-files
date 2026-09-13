#!/usr/bin/env bun

// Run inside a fork: git upstream (or git-upstream).
// Keep only the upstream's default branch, discovering it from the server.

async function git(...args: string[]): Promise<string> {
  const proc = Bun.spawn(["git", ...args], {
    stdin: "inherit",
    stdout: "pipe",
    stderr: "inherit",
  });
  const output = await new Response(proc.stdout).text();
  if ((await proc.exited) !== 0) {
    throw new Error(`git ${args[0]} failed; stopping.`);
  }
  return output.trim();
}

async function main() {
  const args = Bun.argv.slice(2);
  if (args.length) {
    if (args.length === 1 && ["--help", "-h"].includes(args[0])) {
      console.log(
        "Usage: git upstream\n\n" +
        "Track only upstream's default branch and remove its other remote-tracking refs.\n" +
        "Prompts for a URL if upstream does not exist. Requires Git and Bun.",
      );
      return;
    }
    throw new Error("Usage: git upstream (no arguments)");
  }

  await git("rev-parse", "--git-dir");
  const exists = (await git("remote")).split("\n").includes("upstream");
  const source = exists ? "upstream" : prompt("Upstream URL:")?.trim();
  if (!source) throw new Error("No upstream URL provided; nothing changed.");

  // Do not trust a potentially stale local upstream/HEAD, or guess main/master.
  const advertised = await git("ls-remote", "--symref", "--", source, "HEAD");
  const branch = advertised.match(/^ref: refs\/heads\/(.+)\tHEAD$/m)?.[1];
  if (!branch || !/^[0-9a-f]+\tHEAD$/m.test(advertised)) {
    throw new Error(
      "Upstream did not advertise an existing default branch; nothing changed.",
    );
  }
  await git("check-ref-format", `refs/heads/${branch}`);

  if (exists) {
    await git("remote", "set-branches", "upstream", branch);
  } else {
    await git("remote", "add", "-t", branch, "--", "upstream", source);
  }

  const defaultRef = `refs/remotes/upstream/${branch}`;
  // Explicit flags also prevent inherited pruning settings from removing tags.
  // Fetch before cleanup so a network failure leaves existing refs intact.
  await git(
    "fetch",
    "--no-tags",
    "--no-prune",
    "--no-prune-tags",
    "--no-recurse-submodules",
    "upstream",
    `+refs/heads/${branch}:${defaultRef}`,
  );
  await git("symbolic-ref", "refs/remotes/upstream/HEAD", defaultRef);

  const refs = (
    await git("for-each-ref", "--format=%(refname)", "refs/remotes/upstream/")
  ).split("\n");
  let removed = 0;
  for (const ref of refs) {
    if (!ref || ref === defaultRef || ref === "refs/remotes/upstream/HEAD") {
      continue;
    }
    // Never follow a symbolic ref into a local branch or another remote.
    await git("update-ref", "--no-deref", "-d", ref);
    removed++;
  }
  console.log(
    `Upstream now tracks only ${branch}; removed ${removed} other remote-tracking reference(s).`,
  );
}

try {
  await main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}
