#!/usr/bin/env -S nix shell -iv -k HOME me#bun me#nix me#git me#openssh me#fd me#bash me#cargo me#rustCrates.cargo-crate -c bun run

import * as fs from "node:fs";
import * as path from "node:path";
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

await $`git commit add "${import.meta.dirname}/data.nix" 1>&2`.nothrow();
await $`git commit -m "chore(tools): Update custom Rust crates" -- "${import.meta.dirname}/data.nix" 1>&2`.nothrow();

async function fillHashes() {
  const data = await loadData();

  for (const subDerivation of ["src", "cargoDeps"]) {
    for (const crate of TARGET_CRATES) {
      console.log(`Filling ${subDerivation} hash for ${crate}...`);

      const entry = data[crate];
      const { stdout, stderr, code } =
        await $`nix build --no-link "${REPO_DIR}#rustCrates.${crate}.${subDerivation}"`
          .nothrow()
          .quiet();

      if (!code) continue;

      // hash mismatch in fixed-output derivation '/nix/store/ix1lajrq193h5v1d2bpiw61qnpikkkrh-cargo-deps-1.5.1.tar.gz.drv':
      //          specified: sha256-IQZIy+OAzUurfMjvmlQ4NxXY1u6Dt2x+xa0NGeCiqeg=
      //             got:    sha256-qnSHG4AhBrleYKZ4SJ4AwHdJyiidj8NTeSSphBRo7gg=

      try {
        const [, _, found] = stderr.match(
          /hash mismatch in fixed-output derivation .*:\n\s+specified:\s+(\S+)\s*\n\s*got:\s+(\S+)/,
        );

        switch (subDerivation) {
          case "src":
            entry.crateSha256 = found;
            break;
          case "cargoDeps":
            entry.depsHash = found;
            break;
        }
      } catch (error) {
        console.log(`Error on ${crate}:\n`, { code, stdout, stderr, error });
      }
    }

    await saveData(data);
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

    data[crate] = {
      crateSha256: MARKER_HASH,
      depsHash: MARKER_HASH,
      ...data[crate],
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
