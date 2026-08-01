#!/usr/bin/env bash

WT_PATH="$(treehouse get --lease)"

herdr worktree open "$WT_PATH"

treehouse return "$WT_PATH"
