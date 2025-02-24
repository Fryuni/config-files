#!/usr/bin/env bash

set -eo pipefail

export EARLY_CUT_DATE="2025-02-08"
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
      jq ".videos[]|select(.recordedAt > \"${EARLY_CUT_DATE}\")|.id" -r |
      tac
  )

  echo "Downloading VODs"

  for video_id in $VIDEO_IDS; do
    bash ./download-and-store.sh "$video_id"
  done

  export OUT_NAME_FORMAT="$channel/clips/{date}_{id}_{channel_login}_{title_slug}.{format}"

  echo "Downloading clips"

  twitch-dl clips "$channel" --all --json --period last_week |
    jq ".[]|select(.createdAt > \"${EARLY_CUT_DATE}\")|.id" -r |
    tac |
    xargs -P8 -n1 bash ./download-and-store.sh # &>/dev/null
done
