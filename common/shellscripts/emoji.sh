#!/usr/bin/env bash

#=============================================================================
# Inspired by @TheCodeTherapy - https://mgz.me
# Emoji picker
# To use, create a custom keyboard shortcut by following below instructions:
# Settings > Keyboard Shortcuts > +
# Name: Emoji Picker
# Command: [full path to this script file]
# Shortcut: Super + . (or any other you might want)
#=============================================================================

EMOJIS="/home/${USER}/ZShutils/common/emoji/emoji.txt"
THEME="/home/${USER}/ZShutils/common/rofi/sp.theme.rasi"
chosen=$(cut -d ';' -f1 ${EMOJIS} | rofi -dmenu -theme ${THEME} | sed "s/ .*//")
[ -z "$chosen" ] && exit

echo "$chosen" | tr -d '\n' | xclip -selection clipboard
# notify-send -a "Emoji Picker" "'$chosen' copied to clipboard." --expire-time=2100 &

