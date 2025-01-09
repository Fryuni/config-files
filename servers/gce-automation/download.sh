#!/usr/bin/env bash

set -eo pipefail

export BUCKET_NAME="twitch-vods-02057f9"

CHANNELS=(
  fesicuro
)

for channel in "${CHANNELS[@]}"; do
  echo "Downloading data for channel: $channel"

  export OUT_NAME_FORMAT="$channel/vods/{date}_{id}_{channel_login}_{title_slug}.{format}"

  rm -rf ~/.cache/twitch-dl
  rm -rf "$channel"
  mkdir -p "$channel/clips"
  mkdir -p "$channel/vods"

  VIDEO_IDS=$(
    twitch-dl videos "$channel" --all --json |
      jq '.videos[]|select(.recordedAt > "2025-01-08")|.id' -r |
      tac
  )

  for video_id in $VIDEO_IDS; do
    bash ./download-and-store.sh "$video_id"
  done

  export OUT_NAME_FORMAT="$channel/clips/{date}_{id}_{channel_login}_{title_slug}.{format}"

  twitch-dl clips "$channel" --limit 50 --json |
    jq '.[].slug' -r |
    tac |
    xargs -P8 -n1 bash ./download-and-store.sh # &>/dev/null
done
