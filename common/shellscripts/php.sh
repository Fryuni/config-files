#!/usr/bin/env bash

set -eo pipefail

SHIM_NAME="$(basename "$0" .sh)"

args=(
  --rm
  -u "$UID:$GID"
  -v "/run/user/$UID:/run/user/$UID"
  -v /home/lotus:/home/lotus
  -w "$(pwd)"
  -e HOME="$HOME"
)

if [ -t 0 ]; then
  # Stdin is a terminal, bind it to docker
  args+=("-it")
fi

exec docker run "${args[@]}" crocttech/php-base-image:php8.5-dev "$SHIM_NAME" "$@"
