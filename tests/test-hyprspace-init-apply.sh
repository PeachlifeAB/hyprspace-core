#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
source "$root_dir/tests/_common.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
test_home="$(make_temp_dir)"
register_cleanup_path "$test_home"
trap cleanup_paths_on_exit EXIT

echo "[step] applying init facade with sketchybar and borders disabled, plus explicit app preferences"
HYPRSPACE_HOME_OVERRIDE="$test_home" \
    HYPRSPACE_SKIP_DEPENDENCY_SETUP=1 \
    HYPRSPACE_SKIP_MACOS_DEFAULTS=1 \
    HYPRSPACE_SKIP_SKETCHYBAR_SERVICE=1 \
    HYPRSPACE_SKIP_WALLPAPER_SETUP=1 \
    HYPRSPACE_SELECTED_TERMINAL_APP='Terminal.app' \
    HYPRSPACE_SELECTED_MUSIC_APP='Spotify' \
    HYPRSPACE_SELECTED_BROWSER_APP='Helium' \
    "$root_dir/scripts/internal/apply-init-selections.sh" \
    --without-sketchybar \
    --without-borders \
    --without-macos-defaults \
    --without-wallpaper

echo "[step] asserting shaped Hyprspace config"
test -f "$test_home/.config/hyprspace/config.toml"
grep -q "new-window-or-open Terminal.app" "$test_home/.config/hyprspace/config.toml"
grep -q "new-window-or-open Helium" "$test_home/.config/hyprspace/config.toml"
grep -q "new-window-or-open Spotify" "$test_home/.config/hyprspace/config.toml"
if grep -q "sketchybar --trigger hyprspace_workspace_change" "$test_home/.config/hyprspace/config.toml"; then
    echo "[error] sketchybar hook should be absent when sketchybar is disabled"
    exit 1
fi
if grep -q "borders active_color=" "$test_home/.config/hyprspace/config.toml"; then
    echo "[error] borders hook should be absent when borders are disabled"
    exit 1
fi

echo "[step] asserting sketchybar files were not created"
if [ -e "$test_home/.config/sketchybar/sketchybarrc" ]; then
    echo "[error] sketchybar config should not be created when sketchybar is disabled"
    exit 1
fi

echo "[step] asserting mandatory reference files still exist"
test -f "$test_home/.config/hyprspace/docs/default-config.toml"
test -f "$test_home/.config/hyprspace/docs/README.md"
test -f "$test_home/.config/hyprspace/docs/ACKNOWLEDGMENTS.md"

echo "[ok] hyprspace init apply facade test passed"
