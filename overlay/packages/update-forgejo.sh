#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq nix-update gnused git
# shellcheck shell=bash
set -euo pipefail

BRANCH_NAME=${BRANCH_NAME:-forgejo}
REPO_DIR=$(git rev-parse --show-toplevel)
PACKAGE_FILE="$REPO_DIR/overlay/packages/forgejo.nix"
API_URL="https://git.fryuni.dev/api/v1/repos/Fryuni/forgejo/commits?sha=${BRANCH_NAME}&limit=1&stat=false&verification=false&files=false"

commit=false
case "${1:-}" in
  "") commit=true ;;
  --no-commit) ;;
  *)
    echo "usage: $0 [--no-commit]" >&2
    exit 2
    ;;
esac

cd "$REPO_DIR"

commits=$(curl --fail --silent --show-error --location \
  --user-agent "curl" \
  "$API_URL")
rev=$(jq --exit-status --raw-output '.[0].sha' <<<"$commits")
timestamp=$(jq --exit-status --raw-output '.[0].commit.committer.date' <<<"$commits")

if [[ ! "$rev" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Forgejo API returned an invalid commit ID: $rev" >&2
  exit 1
fi
if [[ ! "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]; then
  echo "Forgejo API returned an invalid commit timestamp: $timestamp" >&2
  exit 1
fi

date=${timestamp%%T*}
current_version=$(sed -n 's/^    version = "\([^"]*\)";$/\1/p' "$PACKAGE_FILE")
if [[ -z "$current_version" || "$current_version" != *-unstable-* ]]; then
  echo "Could not determine the unstable Forgejo version from $PACKAGE_FILE" >&2
  exit 1
fi
version_prefix=${current_version%%-unstable-*}
version="$version_prefix-unstable-$date"

sed -i \
  -e 's|^    version = "[^"]*";|    version = "'"$version"'";|' \
  -e 's|^    rev = "[0-9a-f]\{40\}";|    rev = "'"$rev"'";|' \
  "$PACKAGE_FILE"

updated_version=$(sed -n 's/^    version = "\([^"]*\)";$/\1/p' "$PACKAGE_FILE")
updated_rev=$(sed -n 's/^    rev = "\([0-9a-f]\{40\}\)";$/\1/p' "$PACKAGE_FILE")
if [[ "$updated_version" != "$version" || "$updated_rev" != "$rev" ]]; then
  echo "Failed to update Forgejo version and revision in $PACKAGE_FILE" >&2
  exit 1
fi

# Version and revision are resolved above; nix-update refreshes the source,
# Go vendor, and npm dependency hashes for that exact branch commit.
nix-update \
  --version=skip \
  --flake legacyPackages.x86_64-linux.forgejo \
  --override-filename overlay/packages/forgejo.nix

if "$commit"; then
  git add "$PACKAGE_FILE"
  git diff --cached --quiet -- "$PACKAGE_FILE" || \
    git commit -m "chore: Update forgejo" -- "$PACKAGE_FILE"
fi
