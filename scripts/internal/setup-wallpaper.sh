#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
wallpaper_path="${HYPRSPACE_WALLPAPER_PATH:-$ROOT_DIR/artifacts/gfx/wallpaper-default.jpg}"
helper_path="$ROOT_DIR/libexec/hyprspace-init/hyprspace-set-wallpaper"
get_helper_path="$ROOT_DIR/libexec/hyprspace-init/hyprspace-get-wallpaper"
backup_file="$HOME/.config/hyprspace/.wallpaper-backup"

if [ "${HYPRSPACE_SKIP_WALLPAPER_SETUP:-0}" = "1" ]; then
    echo "-> Skipping wallpaper setup (HYPRSPACE_SKIP_WALLPAPER_SETUP=1)."
    exit 0
fi

if [ ! -f "$wallpaper_path" ]; then
    echo "-> Wallpaper asset missing at $wallpaper_path. Skipping wallpaper setup."
    exit 0
fi

if [ ! -x "$helper_path" ]; then
    echo "-> Wallpaper helper missing at $helper_path. Skipping wallpaper setup."
    exit 0
fi

# Save the current wallpaper before overwriting
if [ -x "$get_helper_path" ]; then
    current_wallpaper="$($get_helper_path 2>/dev/null | head -1)" || true
    if [ -n "${current_wallpaper:-}" ] && [ -f "$current_wallpaper" ]; then
        mkdir -p "$(dirname "$backup_file")"
        printf '%s\n' "$current_wallpaper" > "$backup_file"
        echo "-> Saved current wallpaper path to $backup_file"
    fi
else
    echo "-> Wallpaper getter not available, skipping backup."
fi

echo "-> Setting macOS wallpaper from $wallpaper_path..."
if ! output="$($helper_path "$wallpaper_path" 2>&1)"; then
    echo "-> Wallpaper setup failed, continuing without blocking init."
    printf '%s\n' "$output"
    exit 0
fi

if [ -n "$output" ]; then
    printf '%s\n' "$output"
fi

echo "-> Wallpaper applied."
