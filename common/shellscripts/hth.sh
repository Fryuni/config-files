#!/usr/bin/env bash

WID="$(openssl rand -hex 1)"

WT_PATH="$(treehouse get --lease)"

treehouse return "$WT_PATH"

cd "$WT_PATH" || return

if [ -z "$1" ]; then
  git switch -C "wt/$WID"
  WID="main/$WID"
else
  if git switch "$1"; then
    WID="$1"
  else
    git switch -C "wt/$1/$WID" "$1"
    WID="$1/$WID"
  fi
fi

herdr worktree open --path "$WT_PATH" --label "$WID" --focus
