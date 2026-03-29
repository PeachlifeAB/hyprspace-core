#!/bin/sh

case "$SENDER" in
    "cursor_at_top")
        sketchybar --set '/.*/' drawing=off
        ;;
    "cursor_away_from_top")
        sketchybar --set '/.*/' drawing=on
        ;;
esac