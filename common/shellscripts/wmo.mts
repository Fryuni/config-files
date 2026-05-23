#!/usr/bin/env bun

let [branchName, ...args] = Bun.argv.slice(2);

const currentBranch = (await Bun.$`git branch --show-current`.text()).trim();

const localBranches = (await Bun.$`git branch --format='%(refname:short)'`.text())
  .trim()
  .split('\n')
  .filter(ref => ref !== currentBranch);

const remoteBranches = (await Bun.$`git branch --remote --format='%(refname)'`.text())
  .trim()
  .split('\n')
  .filter(ref => !ref.endsWith('/HEAD'))
  .filter(ref => ref.startsWith('refs/remotes/'))
  .map(ref => ref.slice('refs/remotes/'.length));

const allOptions = [...localBranches, ...remoteBranches];

if (!branchName || !allOptions.includes(branchName)) {
  const proc = Bun.spawn({
    cmd: ['gum', 'filter', `--height=10`, '--no-show-help', ...allOptions],
  });

  branchName = (await proc.stdout.text()).trim();
  await proc.exited;
}

console.log(Object.keys(process));

process.execve(
  'echo',
  [ 'workmux', 'add', '--open-if-exists', branchName, ...args, ],
);
