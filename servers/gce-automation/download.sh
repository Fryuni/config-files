#!/usr/bin/env bash

set -eo pipefail

OUT_NAME_FORMAT="fesicuro/{date}_{id}_{channel_login}_{title_slug}.{format}"

VIDEO_IDS=$(
  twitch-dl videos fesicuro --all --json |
    jq '.videos[]|select(.recordedAt > "2025-01-08")|.id' -r |
    tac
)

for video_id in $VIDEO_IDS; do
  echo "Downloading $video_id"

  rm -rf ~/.cache/twitch-dl
  rm -rf fesicuro
  mkdir -p fesicuro

  twitch-dl download \
    --quality 1080p60 \
    --output "$OUT_NAME_FORMAT" \
    "$video_id"

  gcloud storage cp -r fesicuro gs://twitch-vods-02057f9/fesicuro
done
