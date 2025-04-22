#!/usr/bin/env bash

set -eo pipefail

export BUCKET_NAME="twitch-vods-02057f9"

CHANNELS=(
  fesicuro
)

for channel in "${CHANNELS[@]}"; do
  echo "Downloading data for channel: $channel"

  EARLY_CUT_DATE="$(
    gcloud storage objects list \
      "gs://twitch-vods-02057f9/${channel}/vods/*" \
      --limit 1 \
      --sort-by '~name' \
      --format 'get(name)' |
      awk -F'/' '{split($NF, a, "_"); print a[1]}'
  )"
  export EARLY_CUT_DATE
  export OUT_NAME_FORMAT="$channel/vods/{date}_{id}_{channel_login}_{title_slug}.{format}"

  echo "Early cut date: $EARLY_CUT_DATE"

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
