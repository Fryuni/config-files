#!/usr/bin/env bash
# Dispatch overlay package updates from the registry (overlay/registry.nix).
#
# Usage:
#   overlay/update.sh            # run every updateable registry entry
#   overlay/update.sh <name>     # run a single registry entry (e.g. pulumi)
#
# The update plan is rendered by overlay/update.nix from the registry, so this
# script holds no package list of its own.
set -euo pipefail

# Bash 3 compatible for Darwin
REPO_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )
cd "$REPO_DIR"

# UPDATE_FILTER is consumed by update.nix through builtins.getEnv (--impure).
export UPDATE_FILTER="${1:-}"

nix eval --raw --impure --expr \
  'import ./overlay/update.nix { filter = builtins.getEnv "UPDATE_FILTER"; }' \
  | bash
