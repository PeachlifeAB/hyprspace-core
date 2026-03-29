#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_HOME="${HYPRSPACE_HOME_OVERRIDE:-$HOME}"
SKETCHYBAR_CONFIG_DIR="${HYPRSPACE_SKETCHYBAR_CONFIG_DIR_OVERRIDE:-$SCRIPT_HOME/.config/sketchybar}"
SKETCHYBAR_CONFIG_FILE="$SKETCHYBAR_CONFIG_DIR/sketchybarrc"

ensure_sketchybar_companion_assets() {
    mkdir -p "$SKETCHYBAR_CONFIG_DIR/plugins" "$SKETCHYBAR_CONFIG_DIR/helpers"
    shopt -s nullglob
    local plugins=("$ROOT_DIR/configs/sketchybar/plugins/"*.sh)
    local helpers=("$ROOT_DIR/configs/sketchybar/helpers/"*)
    shopt -u nullglob
    if [ "${#plugins[@]}" -gt 0 ]; then
        cp "${plugins[@]}" "$SKETCHYBAR_CONFIG_DIR/plugins/"
        chmod +x "$SKETCHYBAR_CONFIG_DIR/plugins/"*.sh
    fi
    if [ "${#helpers[@]}" -gt 0 ]; then
        cp "${helpers[@]}" "$SKETCHYBAR_CONFIG_DIR/helpers/"
        chmod +x "$SKETCHYBAR_CONFIG_DIR/helpers/"*
    fi
}

repair_sketchybar_workspace_block_if_needed() {
    [ -f "$SKETCHYBAR_CONFIG_FILE" ] || return 0

    python3 - "$SKETCHYBAR_CONFIG_FILE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

has_workspace_script = 'script="$PLUGIN_DIR/hyprspace_workspace.sh"' in text
has_workspace_event = 'sketchybar --add event hyprspace_workspace_change' in text
has_workspace_subscribe = '--subscribe space."$sid" hyprspace_workspace_change' in text
has_workspace_trigger = 'sketchybar --trigger hyprspace_workspace_change FOCUSED_WORKSPACE="$focused"' in text

if has_workspace_script and has_workspace_event and has_workspace_subscribe and has_workspace_trigger:
    raise SystemExit(0)

start_marker = '##### Adding Hyprspace Workspace Indicators #####'
end_marker = '##### Auto-Hide Workaround (macOS Menu Bar) #####'
if start_marker not in text or end_marker not in text:
    raise SystemExit(0)

start = text.index(start_marker)
end = text.index(end_marker)
replacement = '''##### Adding Hyprspace Workspace Indicators #####
# Add Hyprspace-backed workspace items (not Mission Control spaces).
# These will highlight the focused Hyprspace workspace and focus workspaces on click.

sketchybar --add event hyprspace_workspace_change

for sid in $("$HYPRSPACE_BIN" list-workspaces --all 2>/dev/null); do
    space=(
        icon="$sid"
        background.color=0x40ffffff
        background.corner_radius=5
        background.height=25
        background.position=center
        label.position=center
        script="$PLUGIN_DIR/hyprspace_workspace.sh"
        click_script="$HYPRSPACE_BIN workspace $sid"
    )
    sketchybar --add item space."$sid" left \
        --set space."$sid" "${space[@]}" \
        --subscribe space."$sid" hyprspace_workspace_change
done

# Initial highlight on startup
focused="$("$HYPRSPACE_BIN" list-workspaces --focused 2>/dev/null)"
[ -n "$focused" ] && sketchybar --trigger hyprspace_workspace_change FOCUSED_WORKSPACE="$focused"

'''
path.write_text(text[:start] + replacement + text[end:])
PY
}

if [ -f "$SKETCHYBAR_CONFIG_FILE" ]; then
    echo "-> Sketchybar config already exists at $SKETCHYBAR_CONFIG_FILE. Preserving file and repairing Hyprspace assets/wiring if needed."
    ensure_sketchybar_companion_assets
    repair_sketchybar_workspace_block_if_needed
else
    echo "-> Injecting Sketchybar config to $SKETCHYBAR_CONFIG_DIR..."
    ensure_sketchybar_companion_assets
    cp "$ROOT_DIR/configs/sketchybar/sketchybarrc" "$SKETCHYBAR_CONFIG_FILE"
fi

if [ "${HYPRSPACE_SKIP_SKETCHYBAR_SERVICE:-0}" = "1" ]; then
    echo "-> Skipping Sketchybar service restart (HYPRSPACE_SKIP_SKETCHYBAR_SERVICE=1)."
    exit 0
fi

if ! command -v sketchybar >/dev/null 2>&1; then
    echo "-> Sketchybar is not installed. Skipping service restart."
    exit 0
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "-> Homebrew is not available. Skipping Sketchybar service restart."
    exit 0
fi

echo "-> Restarting Sketchybar service..."
brew services restart sketchybar >/dev/null 2>&1 || brew services start sketchybar >/dev/null 2>&1 || true
