#!/usr/bin/env bun

import { $ } from "bun";

const [githubRepoRef, forgejoTarget = 'git.fryuni.dev'] = Bun.argv.slice(2);

const repoInfo = await $`gh repo view ${githubRepoRef} --json ${[
  'name',
  'url',
  'description',
].join(',')} `.json();

const token = (await $`gh auth token`.arrayBuffer());

await $`fj -H ${forgejoTarget} repo migrate ${[
  '--mirror',
  '--service=github',
  '--token',
  repoInfo.url,
  `mirror/${repoInfo.name}`,
]} <${token}`;
