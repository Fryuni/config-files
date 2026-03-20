#!/usr/bin/env bash

set -eo pipefail

AUTH_ARGS=()
if [[ -n "$TWITCH_AUTH_TOKEN" ]]; then
  AUTH_ARGS=(--auth-token "$TWITCH_AUTH_TOKEN")
fi

echo "Probing for $1"

FILE_NAME=$(echo "1" | twitch-dl download "$1" \
  --dry-run \
  --output "$OUT_NAME_FORMAT" \
  "${AUTH_ARGS[@]}" \
  2>&1 | rg -o 'Target: (.*)' -r'$1' || true)

echo "Downloading $1 into $FILE_NAME"

echo 1 | twitch-dl download \
  --output "$OUT_NAME_FORMAT" \
  "${AUTH_ARGS[@]}" \
  "$1" &>/dev/null

echo "Downloaded $FILE_NAME, uploading"

gcloud storage cp "$FILE_NAME" "gs://$BUCKET_NAME/$FILE_NAME" &>/dev/null

echo "Uploaded $FILE_NAME, deleting original file"

rm "$FILE_NAME"

echo "Archival completed for $FILE_NAME"
