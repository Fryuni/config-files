#!/usr/bin/env bash
# Usage: closure-diff.sh TITLE OLD_OUT NEW_OUT
# Prints a Markdown report comparing two build outputs: the dix package diff of
# their closures, then a unified diff of the text files they contain.
# Needs dix, diffutils, findutils, gnugrep, gnused and coreutils on PATH.
# shellcheck disable=SC2016 # backticks in single quotes are Markdown, not expansions
set -euo pipefail

title=$1 old=$2 new=$3
max_chars=50000

# Copy the text files of a dereferenced output with store hashes masked, so the
# diff shows content changes rather than every rebuilt dependency's new path.
# Package environments, firmware and kernel modules are left to dix.
snapshot() {
  local src=$1 dst=$2
  mkdir -p "$dst"
  # find -L reports dangling links and loops on stderr; those are not content.
  # Links out of the store (e.g. etc/mtab) read the same host file on both sides.
  (
    cd "$src"
    # Specialisations are nested system outputs with the same layout.
    find -L . -regextype posix-extended \
      -regex '\./(specialisation/[^/]+/)?(sw|etc/profiles|home-path|firmware|kernel-modules)' -prune \
      -o -type f -size -1024k -print0 2>/dev/null || true
  ) | sort -zu | (cd "$src" && xargs -0r grep -IlZ '' -- || true) | # text files only
    (cd "$src" && xargs -0r cp -L --parents --no-preserve=mode -t "$dst" --) \
      2> >(grep -v 'specified more than once' >&2) # store-optimised hardlinks
  find "$dst" -type f -exec sed -i -E 's|/nix/store/[0-9a-z]{32}-|/nix/store/…-|g' {} +
}

# Wrap text in a fence that cannot be closed by backticks inside it.
fenced() {
  local lang=$1 body=$2
  if ((${#body} > max_chars)); then
    body="${body:0:max_chars}"$'\n'"… truncated, run the diff locally for the rest"
  fi
  printf '````%s\n%s\n````\n' "$lang" "$body"
}

if [[ $old == "$new" ]]; then
  printf '### Closure diff: %s\n\nNo changes: `%s` is identical to the base branch.\n' "$title" "$new"
  exit
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
snapshot "$old" "$tmp/old"
snapshot "$new" "$tmp/new"
# diff exits 1 when the trees differ; only 2 is an error.
files=$(cd "$tmp" && diff -ruN old new | sed -E '/^(---|\+\+\+) /s/\t.*//') || [[ $? == 1 ]]
packages=$(dix diff --color=never "$old" "$new")

echo "### Closure diff: $title"
echo
echo "\`$old\` (base) → \`$new\` (PR)"
echo
echo "<details open><summary>Packages</summary>"
echo
fenced "" "$packages"
echo
echo "</details>"
echo
if [[ -z $files ]]; then
  echo "No text file differences."
else
  echo "<details><summary>Files ($(grep -c '^diff ' <<<"$files") changed)</summary>"
  echo
  fenced diff "$files"
  echo
  echo "</details>"
fi
