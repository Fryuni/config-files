#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Info:
#   author:    Miroslav Vidovic
#   file:      web-search.sh
#   created:   24.02.2017.-08:59:54
#   revision:  ---
#   version:   1.0
# -----------------------------------------------------------------------------
# Requirements:
#   rofi
# Description:
#   Use rofi to search the web.
# Usage:
#   web-search.sh
# -----------------------------------------------------------------------------
# Script:

THEME="/home/${USER}/ZShutils/rofi/sp.theme.rasi"

declare -A URLS

URLS=(
  # Rust search
  ["crates"]="https://crates.io/search?q="
  ["docsrs"]="https://docs.rs/"
  ["ruststd"]="https://doc.rust-lang.org/std/?search="

  ["lib"]="https://libraries.io/search?q="
  ["godev"]="https://pkg.go.dev/search?q="

  ["google"]="https://www.google.com/search?q="
  ["bing"]="https://www.bing.com/search?q="
  ["yahoo"]="https://search.yahoo.com/search?p="
  ["duckduckgo"]="https://www.duckduckgo.com/?q="
  ["github"]="https://github.com/search?q="
  ["goodreads"]="https://www.goodreads.com/search?q="
  ["stackoverflow"]="http://stackoverflow.com/search?q="
  ["symbolhound"]="http://symbolhound.com/?q="
  ["searchcode"]="https://searchcode.com/?q="
  ["openhub"]="https://www.openhub.net/p?ref=homepage&query="
  ["superuser"]="http://superuser.com/search?q="
  ["askubuntu"]="http://askubuntu.com/search?q="
  ["piratebay"]="https://thepiratebay.org/search/"
  ["youtube"]="https://www.youtube.com/results?search_query="
  ["vimawesome"]="http://vimawesome.com/?q="
)

# List for rofi
gen_list() {
    for i in "${!URLS[@]}"
    do
      echo "$i"
    done
}

main() {
  # Pass the list to rofi
  platform=$( (gen_list) | rofi -dmenu -theme "${THEME}" -matching fuzzy -no-custom -location 0 -p "Search > " )

  if [[ -n "$platform" ]]; then
    query=$( (echo ) | rofi  -dmenu -theme "${THEME}" -matching fuzzy -location 0 -p "Query > " )

    if [[ -n "$query" ]]; then
      url=${URLS[$platform]}$query
      xdg-open "$url"
    else
      exit
    fi

  else
    exit
  fi
}

main

exit 0
