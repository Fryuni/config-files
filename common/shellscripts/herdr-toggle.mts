#!/usr/bin/env bun

import { $ } from 'bun';

const targetName = process.argv[2].toLowerCase();

if (!targetName) {
  console.error('Pass in a name to toggle');
  process.exit(1);
}

const herdrBin = process.env.HERDR_BIN_PATH || 'herdr';

type Machine = {
  id: string;
  label: string;
  target: string;
  session: string;
  enabled: boolean;
  selected: boolean;
}

const machines: Machine[] = await $`${herdrBin} machine list --json`.json();

const targetMachine = machines.find(machine => (
machine.label.toLowerCase() === targetName
    || machine.target.toLowerCase() === targetName
));

if (!targetMachine) {
  console.error(`No machine found for target ${JSON.stringify(targetName)}.`);
  console.error('Known machines:')
  console.error(
    machines.map(machine => `  - ${JSON.stringify(machine.label)} -> ${JSON.stringify(machine.target)}`)
    .join('\n')
  );
  process.exit(1);
}

console.log(`Toggling ${targetMachine.label} -> @${targetMachine.target}`);

if (targetMachine.enabled) {
  await $`${herdrBin} machine disable ${targetMachine.id}`;
} else {
  await $`${herdrBin} machine enable ${targetMachine.id}`;
}
