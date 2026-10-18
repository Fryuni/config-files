#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq nix-update git
# shellcheck shell=bash
# Pin a package to the latest commit on a branch of its Forgejo-hosted fork.
#
# Usage: overlay/update-fork.sh <name> <branch> <file> [--no-commit]
#
#   name   - flake package (packages.x86_64-linux.<name>) built from the fork
#   branch - fork branch to follow
#   file   - repository-relative file that declares the version, rev, and hashes
#
# For forks whose tags don't give a usable version prefix, such as one carrying
# upstream's backport tags, which nix-update's branch mode would pick from.
# The branch head is resolved here through the Forgejo API, the existing version
# prefix is kept, and nix-update only refreshes hashes for that exact commit.
set -euo pipefail

usage() {
  echo "usage: $0 <name> <branch> <file> [--no-commit]" >&2
  exit 2
}

[[ $# -eq 3 || $# -eq 4 ]] || usage
name=$1
branch=$2
file=$3
commit=false
case "${4:-}" in
  "") commit=true ;;
  --no-commit) ;;
  *) usage ;;
esac

REPO_DIR=$(git rev-parse --show-toplevel)
cd "$REPO_DIR"

package=$(nix eval --json ".#packages.x86_64-linux.$name" --apply \
  'p: { inherit (p) version; inherit (p.src) rev gitRepoUrl; }')
current_version=$(jq --exit-status --raw-output '.version' <<<"$package")
current_rev=$(jq --exit-status --raw-output '.rev' <<<"$package")
repo_url=$(jq --exit-status --raw-output '.gitRepoUrl' <<<"$package")

if [[ ! "$repo_url" =~ ^(https://[^/]+)/([^/]+/[^/]+)\.git$ ]]; then
  echo "Unsupported fork repository URL for $name: $repo_url" >&2
  exit 1
fi
api_url="${BASH_REMATCH[1]}/api/v1/repos/${BASH_REMATCH[2]}/commits?sha=${branch}&limit=1&stat=false&verification=false&files=false"

# Cloudflare only lets curl User-Agents through when they identify as Nix.
commits=$(curl --fail --silent --show-error --location \
  --user-agent "nix-files-fork-updater" \
  "$api_url")
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

if [[ "$rev" == "$current_rev" ]]; then
  echo "$name is already at the head of $branch ($rev)"
  exit 0
fi

if [[ "$current_version" != *-unstable-* ]]; then
  echo "Could not determine the unstable version prefix of $name from $current_version" >&2
  exit 1
fi
version="${current_version%%-unstable-*}-unstable-${timestamp%%T*}"

# Replace the exact quoted values so other packages in the same file are untouched.
replace_once() {
  local old="\"$1\"" new="\"$2\"" content count
  count=$(grep --count --fixed-strings -- "$old" "$file" || true)
  if [[ "$count" != 1 ]]; then
    echo "Expected exactly one $old in $file, found $count" >&2
    exit 1
  fi
  content=$(<"$file")
  printf '%s\n' "${content/"$old"/"$new"}" >"$file"
}

# The early exit above trusts a matching rev, so never leave a new rev behind
# with stale hashes: restore the original pin unless the refresh completes.
backup=$(mktemp)
cp -- "$file" "$backup"
trap 'cp -- "$backup" "$file"; rm -f -- "$backup"' EXIT

replace_once "$current_version" "$version"
replace_once "$current_rev" "$rev"

# Version and revision are resolved above; nix-update refreshes the source
# and dependency hashes for that exact branch commit.
nix-update \
  --version=skip \
  --flake \
  --system x86_64-linux \
  --override-filename "$file" \
  "$name"

trap - EXIT
rm -f -- "$backup"

if "$commit"; then
  git add "$file"
  git diff --cached --quiet -- "$file" ||
    git commit -m "chore: Update $name" -- "$file"
fi
