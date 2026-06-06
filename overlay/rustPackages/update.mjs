#!/usr/bin/env -S nix shell -iv -k HOME me#bun me#nix me#git me#openssh me#fd me#bash me#cargo me#rustCrates.cargo-crate -c bun run

import * as fs from "node:fs";
import { $ } from "bun";

process.chdir(import.meta.dirname);

const REPO_DIR = (await $`git rev-parse --show-toplevel`.text()).trim();

const TARGET_CRATES =
  process.argv.length > 2
    ? process.argv.slice(2)
    : Object.keys(await loadData());

const MARKER_HASH = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

await prefillData();
await fillHashes();

process.chdir(REPO_DIR);

await $`git add "${import.meta.dirname}/data.nix" 1>&2`.nothrow();
await $`git commit -m "chore(tools): Update custom Rust crates" -- "${import.meta.dirname}/data.nix" 1>&2`.nothrow();

async function fillHashes() {
  const data = await loadData();

  for (const crate of TARGET_CRATES) {
    const entry = data[crate];

    for (const [subDerivation, hashAttr] of [
      ["src", "crateSha256"],
      ["cargoDeps", "depsHash"],
    ]) {
      console.log(`Filling ${subDerivation} hash for ${crate}...`);

      const { stdout, stderr, exitCode } =
        await $`nix build --no-link "${REPO_DIR}#rustCrates.${crate}.${subDerivation}"`
          .nothrow()
          .quiet();

      if (exitCode === 0) {
        if (entry[hashAttr] === MARKER_HASH) {
          throw new Error(
            `${crate}.${subDerivation} built successfully with the marker hash still in data.nix`,
          );
        }

        continue;
      }

      entry[hashAttr] = extractHashMismatch(`${stdout}\n${stderr}`);

      await saveData(data);
    }
  }
}

async function prefillData() {
  const data = await loadData();

  for (const crate of TARGET_CRATES) {
    console.log(`Prefilling ${crate}...`);
    const {
      owners,
      krate: { crate: crateInfo },
    } = await $`cargo crate info --json ${crate}`.json();

    const previous = data[crate] ?? {};
    const versionChanged = previous.version !== crateInfo.max_version;

    data[crate] = {
      ...previous,
      crateSha256: versionChanged
        ? MARKER_HASH
        : (previous.crateSha256 ?? MARKER_HASH),
      depsHash: versionChanged ? MARKER_HASH : (previous.depsHash ?? MARKER_HASH),
      id: crateInfo.id,
      description: crateInfo.description,
      version: crateInfo.max_version,
      homepage: crateInfo.homepage,
      keywords: crateInfo.keywords?.sort(),
      owners: owners,
    };
  }

  await saveData(data);
}

function extractHashMismatch(output) {
  // hash mismatch in fixed-output derivation '/nix/store/ix1lajrq193h5v1d2bpiw61qnpikkkrh-cargo-deps-1.5.1.tar.gz.drv':
  //          specified: sha256-IQZIy+OAzUurfMjvmlQ4NxXY1u6Dt2x+xa0NGeCiqeg=
  //             got:    sha256-qnSHG4AhBrleYKZ4SJ4AwHdJyiidj8NTeSSphBRo7gg=
  const match = output.match(
    /hash mismatch in fixed-output derivation .*:\n\s+specified:\s+\S+\s*\n\s*got:\s+(\S+)/,
  );

  if (!match) {
    throw new Error(`Could not extract hash mismatch from build output:\n${output}`);
  }

  return match[1];
}

async function loadData() {
  return await $`nix eval --json --impure --expr 'import ./data.nix'`
    .json()
    .catch(() => ({}));
}

async function saveData(data) {
  console.log("Saving data object!");

  const jsonData = JSON.stringify(JSON.stringify(data));

  const content =
    await $`nix eval --impure --expr 'builtins.fromJSON(${jsonData})'`.text();

  await fs.promises.writeFile(
    "data.nix",
    [
      "# DO NOT EDIT! This file is generated automatically by update.mjs",
      content,
    ].join("\n"),
    { encoding: "utf8" },
  );

  const cwd = process.cwd();
  console.log(REPO_DIR);
  process.chdir(REPO_DIR);
  await $`nix fmt "${import.meta.dirname}/data.nix"`.nothrow();
  process.chdir(cwd);
}
