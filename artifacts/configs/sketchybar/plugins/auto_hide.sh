#!/bin/sh

case "$SENDER" in
"cursor_at_top")
    sketchybar --bar hidden=on
    ;;
"cursor_away_from_top")
    sketchybar --bar hidden=off
    ;;
esac
