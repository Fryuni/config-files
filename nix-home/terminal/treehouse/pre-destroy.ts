#!/usr/bin/env bun

const proc = Bun.spawn(["zoxide", "remove", process.cwd()], {
  stdout: "inherit",
  stderr: "inherit",
});

process.exit(await proc.exited);
