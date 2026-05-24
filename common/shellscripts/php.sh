#!/usr/bin/env bash

set -eo pipefail

SHIM_NAME="$(basename "$0" .sh)"

exec docker run -it --rm \
  -u "$UID:$GID" \
  -v "/run/user/$UID:/run/user/$UID" \
  -v /home/lotus:/home/lotus \
  -w "$(pwd)" \
  -e HOME="$HOME" \
  crocttech/php-base-image:php8.5-dev \
  "$SHIM_NAME" "$@"
