#!/usr/bin/env bun

import * as os from 'node:os';
import { $ } from "bun";

const entries = await Array.fromAsync(new Bun.Glob('*/*').scan({
  cwd: `${os.homedir()}/.t3/worktrees`,
  absolute: true,
  onlyFiles: false,
}));

for (const treePath of entries) {
  const res = await $`git status --porcelain`
    .cwd(treePath)
    .text();

  if (res.trim() !== '') {
    console.log(`Dirty state on "${treePath}":\n${res}`);
    continue;
  }

  console.log(`Cleaning "${treePath}"`);

  const commonDir = await $`git rev-parse --git-common-dir`
    .cwd(treePath)
    .text();

  await $`git worktree remove ${treePath}`
    .cwd(commonDir.trim());
}
