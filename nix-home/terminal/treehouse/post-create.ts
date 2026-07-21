#!/usr/bin/env bun

const proc = Bun.spawn(["zoxide", "add", process.cwd()], {
  stdout: "inherit",
  stderr: "inherit",
});

process.exit(await proc.exited);
