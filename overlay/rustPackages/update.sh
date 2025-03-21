#!/usr/bin/env -S nix shell -iv -k HOME .#bash .#nix .#git .#findutils .#cargo .#alejandra .#ripgrep .#rustCrates.cargo-crate .#jq .#moreutils .#coreutils .#nix-prefetch -c bash --
# shellcheck shell=bash

# set -x
set -eo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd "$SCRIPT_DIR"

REPO_DIR="$(git rev-parse --show-toplevel)"

# An array of plugin names. The respective repository inside Pulumi's
# Github organization is called pulumi-$name by convention.

declare -a cargo_crates

if [ $# -eq 0 ]; then
	cargo_crates=(
		# "bootimage"
		"cargo-deps"
		"cargo-expand"
		# "cargo-watch"
		"cargo-crate"
		"cargo-edit"
		# "cargo-sort"
		# "cargo-cache"
		# "cargo-public-api"
		# "cargo-semver-checks"
		"cargo-lock"
		"cargo-docs"
		# "toml-merge"
		"zellij"
		"prr"
	)
else
	cargo_crates=("$@")
fi

out_file=$(readlink -f data.nix)

function genLatest() {
	local crate="${1}"
	local tmpdir="${2}"

	echo "Retrieving latest version of ${crate}..."

	cargo crate info --json "$crate" |
		jq '{owners} + (.krate.crate|{id,description,homepage,keywords:(.keywords|sort),version:.max_version})' \
			>"${tmpdir}/${crate}_latest.json"

	local version
	version=$(jq -r '.version' "${tmpdir}/${crate}_latest.json")

	if [[ -f "${tmpdir}/${crate}_${version}.json" ]]; then
		rm "${tmpdir}/${crate}_latest.json"
	else
		echo "Latest version of ${crate} is ${version}."

		mv "${tmpdir}/${crate}_latest.json" "${tmpdir}/${crate}_${version}.json"
		prefetch "$crate" "$version" "$tmpdir"

		# echo "\"${crate}\"=$${\"${crate}_${version}\"};" >"${tmpdir}/${crate}.p.nix"
	fi
}

function capture_hash() {
	local err
	err=$("$@" 2>&1 || :)

	local hash_val
	hash_val=$(printf "%s" "$err" | rg -o 'got: +(.+)$' -r '$1' || :)

	if [ -n "$hash_val" ]; then
		echo "$hash_val"
	else
		printf >&2 "Could not capture the hash from:\n%s" "$err"
		return 1
	fi
}

function prefetch() {
	local crate="${1}"
	local version="${2}"
	local tmpdir="${3}"

	echo "Prefetching crate: ${crate}"

	local crateSha256
	crateSha256=$(nix-prefetch fetchCrate --pname "$crate" --version "$version" 2>/dev/null)

	if [ -n "$crateSha256" ]; then
		echo "Captured crate hash for ${crate}@${version}: ${crateSha256}"

		local depsHash
		depsHash=$(capture_hash nix build --no-link --impure --expr "
		  with builtins.getFlake \"${REPO_DIR}\"; 
		  with legacyPackages.\${builtins.currentSystem};
      (fenixPlatform.buildRustPackage rec {
        pname = \"${crate}\";
        version = \"${version}\";
		    src = fetchCrate {
		      inherit pname version;
          sha256 = \"${crateSha256}\";
        };
        cargoHash = \"\";
      }).cargoDeps")

		echo "Captured dependencies hash for ${crate}@${version}: ${depsHash}"

		{
			if [[ -f $out_file ]]; then
				echo -n "${crate} = (
			  ((import $out_file).${crate} or {})
				// (builtins.fromJSON (builtins.readFile ${tmpdir}/${crate}_${version}.json)
				// {
			    crateSha256 = \"${crateSha256}\";
			    depsHash = \"${depsHash}\";
			  })
			);"
			else
				echo -n "${crate} = (
				builtins.fromJSON (builtins.readFile ${tmpdir}/${crate}_${version}.json) // {
			    crateSha256 = \"${crateSha256}\";
			    depsHash = \"${depsHash}\";
			  }
			);"
			fi
		} >"${tmpdir}/${crate}_${version}.p.nix"
	fi
}

function genSrcs() {
	local tmpdir
	tmpdir="$(mktemp -d)"

	echo "Running with temp dir: $tmpdir"

	for crate in "${cargo_crates[@]}"; do
		genLatest "${crate}" "${tmpdir}" &
	done

	wait

	local tmpout="${tmpdir}/out.nix"

	echo "{" >"$tmpout"
	find "${tmpdir}" -name '*.p.nix' -print0 | sort -z | xargs -r0 cat >>"$tmpout"
	echo "}" >>"$tmpout"

	{
		cat <<EOF
# DO NOT EDIT! This file is generated automatically by update.sh
EOF

		if [[ -f $out_file ]]; then
			nix eval --impure --expr "
	    let
	      original = import $out_file;
	      updated = import $tmpout;
	    in
	    original // updated"
		else
			nix eval --impure --expr "import $tmpout"
		fi
	} | sponge "$out_file"

	rm -r "${tmpdir}"
}

genSrcs

alejandra "${SCRIPT_DIR}/data.nix"
git commit -m "chore(tools): Update custom Rust crates" -- "${SCRIPT_DIR}/data.nix" || true
