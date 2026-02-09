#!/usr/bin/env bash
set -euo pipefail

current_wt="$(git rev-parse --show-toplevel)"

worktrees=$(git worktree list --porcelain | awk '
  $1=="worktree" { path=$2 }
  $1=="branch" { if (path != "'"$current_wt"'") print path }
')

if [[ -z "$worktrees" ]]; then
  echo "No other worktrees found."
  exit 1
fi

target_wt=$(echo "$worktrees" | gum filter --placeholder="Select target worktree...")

if [[ -z "$target_wt" ]]; then
  echo "No worktree selected, aborting."
  exit 1
fi

echo "Copying untracked files from:"
echo "  $current_wt"
echo "to:"
echo "  $target_wt"
echo

copied=0
skipped=0
overwritten=0

while IFS= read -r file; do
  if [[ -f "$file" ]]; then
    target_file="$target_wt/$file"

    if [[ ! -f "$target_file" ]]; then
      mkdir -p "$(dirname "$target_file")"
      cp "$file" "$target_file"
      echo "  [copied] $file"
      ((copied++)) || true
    elif cmp -s "$file" "$target_file"; then
      echo "  [skipped-same] $file"
      ((skipped++)) || true
    else
      echo
      echo "File differs: $file"
      delta "$target_file" "$file" || true
      if gum confirm "Overwrite in target?" </dev/tty; then
        cp "$file" "$target_file"
        echo "  [overwritten] $file"
        ((overwritten++)) || true
      else
        echo "  [skipped] $file"
        ((skipped++)) || true
      fi
    fi
  fi
done < <(git ls-files --others --ignored --exclude-standard | grep -v -E '^(node_modules/|vendor/|build/|coverage/|\.wt/|\.direnv/|unsafe)')

echo
echo "Done. Copied: $copied, Overwritten: $overwritten, Skipped: $skipped"
