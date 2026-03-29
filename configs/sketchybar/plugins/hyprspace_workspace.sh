#!/bin/sh

HYPRSPACE_BIN="${HYPRSPACE_BIN:-$HOME/.local/bin/hyprspace}"
if [ ! -x "$HYPRSPACE_BIN" ]; then
    HYPRSPACE_BIN="$(command -v hyprspace 2>/dev/null || true)"
fi

# The hyprspace_workspace_change event can supply FOCUSED_WORKSPACE.
# The item invoking this script is in $NAME.

if [ "$SENDER" = "hyprspace_workspace_change" ] || [ -z "$SENDER" ]; then
    sid="${NAME#space.}"

    focused="$FOCUSED_WORKSPACE"
    if [ -z "$focused" ]; then
        focused="$("$HYPRSPACE_BIN" list-workspaces --focused 2>/dev/null)"
    fi

    [ -z "$focused" ] && exit 0

    if [ "$sid" = "$focused" ]; then
        sketchybar --set "$NAME" background.drawing=on
    else
        sketchybar --set "$NAME" background.drawing=off
    fi
fi
