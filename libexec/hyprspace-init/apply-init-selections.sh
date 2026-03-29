#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

enable_sketchybar="${HYPRSPACE_ENABLE_SKETCHYBAR:-1}"
enable_borders="${HYPRSPACE_ENABLE_BORDERS:-1}"
enable_macos_defaults="${HYPRSPACE_ENABLE_MACOS_DEFAULTS:-1}"
enable_wallpaper="${HYPRSPACE_ENABLE_WALLPAPER:-1}"
selected_terminal_app="${HYPRSPACE_SELECTED_TERMINAL_APP:-Ghostty}"
selected_music_app="${HYPRSPACE_SELECTED_MUSIC_APP:-Apple Music}"
selected_browser_app="${HYPRSPACE_SELECTED_BROWSER_APP:-Safari}"

while [ $# -gt 0 ]; do
    case "$1" in
    --with-sketchybar) enable_sketchybar=1 ;;
    --without-sketchybar) enable_sketchybar=0 ;;
    --with-borders) enable_borders=1 ;;
    --without-borders) enable_borders=0 ;;
    --with-macos-defaults) enable_macos_defaults=1 ;;
    --without-macos-defaults) enable_macos_defaults=0 ;;
    --with-wallpaper) enable_wallpaper=1 ;;
    --without-wallpaper) enable_wallpaper=0 ;;
    *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
    esac
    shift
done

export HYPRSPACE_ENABLE_SKETCHYBAR="$enable_sketchybar"
export HYPRSPACE_ENABLE_BORDERS="$enable_borders"
export HYPRSPACE_ENABLE_MACOS_DEFAULTS="$enable_macos_defaults"
export HYPRSPACE_ENABLE_WALLPAPER="$enable_wallpaper"
export HYPRSPACE_SELECTED_TERMINAL_APP="$selected_terminal_app"
export HYPRSPACE_SELECTED_MUSIC_APP="$selected_music_app"
export HYPRSPACE_SELECTED_BROWSER_APP="$selected_browser_app"

echo "======================================================"
echo "📦 Applying selected Hyprspace init steps..."
echo "======================================================"

"$ROOT_DIR/scripts/internal/setup-dependencies.sh"
"$ROOT_DIR/scripts/internal/setup-hyprspace-config.sh"

if [ "$enable_sketchybar" = "1" ]; then
    "$ROOT_DIR/scripts/internal/setup-sketchybar-config.sh"
else
    echo "-> Sketchybar bootstrap disabled, skipping."
fi

if [ "$enable_macos_defaults" = "1" ]; then
    "$ROOT_DIR/scripts/internal/setup-macos-defaults.sh"
else
    echo "-> macOS defaults disabled, skipping."
fi

if [ "$enable_wallpaper" = "1" ]; then
    "$ROOT_DIR/scripts/internal/setup-wallpaper.sh"
else
    echo "-> Wallpaper setup disabled, skipping."
fi
