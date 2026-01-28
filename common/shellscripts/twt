#!/usr/bin/env bash
# twt - tmux worktree: manage git worktrees and start a new tmux session in them

set -euo pipefail

git_main_branch() {
  command git rev-parse --git-dir &>/dev/null || return
  local remote ref
  for ref in refs/{heads,remotes/{origin,upstream}}/{main,trunk,mainline,default,stable,master}; do
    if command git show-ref -q --verify "$ref"; then
      echo "${ref}"
      return 0
    fi
  done
  for remote in origin upstream; do
    ref=$(command git rev-parse --abbrev-ref $remote/HEAD 2>/dev/null)
    if [[ "$ref" == "$remote/*" ]]; then
      echo "${ref#"$remote/"}"
      return 0
    fi
  done
  echo master
  return 1
}

base_dir="$HOME/.local/share/git_worktrees"
root_dir="$(dirname "$(git rev-parse --git-common-dir)")"

# Get the root of the git repository
cd "$root_dir"

name="$(basename "$(realpath "$root_dir")")"

# Get existing branches (local + remote). Remote branches exclude the 'origin/' prefix.
branches=$(
  {
    git for-each-ref --format='%(refname:short)' refs/heads
    git for-each-ref --format='%(refname:short)' refs/remotes/origin | sed 's|^origin/||'
  } | sort -u
)

# Build options: existing branches + NEW option
options="NEW"
if [[ -n "$branches" ]]; then
  options=$(printf "%s\n%s" "$options" "$branches")
fi

# Use gum to select a worktree or NEW
selected=$(echo "$options" | gum filter --placeholder="Select worktree or NEW...")

if [[ "$selected" == "NEW" ]]; then
  # Ask for a new branch name
  branch_name=$(gum input --placeholder="Enter new branch name...")

  if [[ -z "$branch_name" ]]; then
    echo "No branch name provided, aborting."
    exit 1
  fi
  git branch "$branch_name" "$(git_main_branch)"
  selected="$branch_name"
fi

# Turn branch into a valid tmux session name
SESSION_NAME="${name//[^a-zA-Z0-9]/_}_${selected//[^a-zA-Z0-9]/_}"

existing_wt_path="$(git worktree list --porcelain | awk -v br="$selected" '
  $1=="worktree"{p=$2}
  $1=="branch"{
    b=$2
    sub(/^refs\/heads\//,"",b)
    if (b==br) { print p; exit }
  }')"

if [[ -n "$existing_wt_path" ]]; then
  echo "Worktree for branch '$selected' already exists at: $existing_wt_path"
  selected="$existing_wt_path"
else
  # Compute hash of the root dir to create a unique git dir for the worktree
  git_dir_hash=$(echo -n "$root_dir" | sha1sum | awk '{print $1}')

  worktree_path="${base_dir}/${git_dir_hash}/${name}_${branch_name}"

  mkdir -p "$(dirname "$worktree_path")"

  git worktree add "$worktree_path" "$selected"

  # Copy untracked files (not ignored by git) to the new worktree
  # Exclude well-known package directories
  echo "Copying untracked files to new worktree..."
  git ls-files --others --ignored --exclude-standard |
    grep -v -E '^(node_modules/|vendor/|\.wt/|\.direnv/|unsafe)' |
    while IFS= read -r file; do
      if [[ -f "$file" ]]; then
        target_dir="$worktree_path/$(dirname "$file")"
        mkdir -p "$target_dir"
        cp "$file" "$worktree_path/$file"
      fi
    done

  echo "Created worktree at $worktree_path"
  selected="$worktree_path"
fi

FULL_PATH=$(realpath "$selected")

echo "Starting tmux session in worktree: $selected"

# determine if the tmux server is running
if tmux list-sessions &>/dev/null; then
  TMUX_RUNNING=0
else
  TMUX_RUNNING=1
fi

# determine the user's current position relative tmux:
# serverless - there is no running tmux server
# attached   - the user is currently attached to the running tmux server
# detached   - the user is currently not attached to the running tmux server
T_RUNTYPE="serverless"
if [ "$TMUX_RUNNING" -eq 0 ]; then
  if [ "$TMUX" ]; then # inside tmux
    T_RUNTYPE="attached"
  else # outside tmux
    T_RUNTYPE="detached"
  fi
fi

if [ "$T_RUNTYPE" != "serverless" ]; then
  SESSION=$(tmux list-sessions -F '#S' | grep "^$SESSION_NAME$" || :) # find existing session
fi

if [ "$SESSION" = "" ]; then # session is missing
  SESSION="$SESSION_NAME"
  if [ -e "$FULL_PATH/.t" ]; then
    tmux new-session -d -s "$SESSION" -c "$FULL_PATH" "$FULL_PATH/.t" # create session and run .t startup script
  else
    tmux new-session -d -s "$SESSION" -c "$FULL_PATH" # create session
  fi
fi

echo "Attaching to tmux session: $SESSION_NAME"
case $T_RUNTYPE in # attach to session
attached)
  exec tmux switch-client -t "$SESSION"
  ;;
detached | serverless)
  exec tmux attach -t "$SESSION"
  ;;
esac
