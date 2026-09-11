#!/usr/bin/env bash

export OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true

declare port

# Look for "--port=123"
for arg in "$@"; do
  if [[ "$arg" == --port=* ]]; then
    port="${arg#--port=}"
    break
  fi
done

# Look for "--port 123"
if [[ -z "$port" ]]; then
  declare -a args=("$@")
  declare -i index
  for ((index = 1; index <= ${#args}; index++)); do
    if [[ "${args[index]}" == --port ]]; then
      port="${args[index + 1]}"
      break
    fi
  done
fi

# If an explicit port was given
if [[ -n "$port" ]]; then
  export OPENCODE_PORT="$port" 
  exec opencode "$@"
fi


# Get an available ephemeral port
port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()') || exit 1

export OPENCODE_PORT="$port"

exec opencode --port "$port" "$@"
