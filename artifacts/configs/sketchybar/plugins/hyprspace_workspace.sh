#!/bin/sh

if [ -n "${HYPRSPACE_BIN:-}" ]; then
    HYPRSPACE_BIN="$HYPRSPACE_BIN"
elif command -v brew >/dev/null 2>&1; then
    HYPRSPACE_BIN="$(brew --prefix)/bin/hyprspace"
elif [ "$(uname -m)" = "arm64" ]; then
    HYPRSPACE_BIN="/opt/homebrew/bin/hyprspace"
else
    HYPRSPACE_BIN="/usr/local/bin/hyprspace"
fi

if [ ! -x "$HYPRSPACE_BIN" ]; then
    HYPRSPACE_BIN="$(command -v hyprspace 2>/dev/null || true)"
fi

# The hyprspace_workspace_change event can supply FOCUSED_WORKSPACE.
# The item invoking this script is in $NAME.

[ -z "$NAME" ] && exit 0

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
