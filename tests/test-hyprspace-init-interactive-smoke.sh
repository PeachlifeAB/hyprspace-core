#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
runtime_src="$root_dir/libexec/hyprspace-init"
source "$root_dir/tests/_common.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
fake_install_root="$(make_temp_dir)"
fake_runtime_dir="$fake_install_root/libexec/hyprspace-init"
test_home="$(make_temp_dir)"
log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-init-interactive-smoke.log"

if [[ ! -d "$root_dir/AeroSpace/docs/config-examples" ]]; then
    echo "[prereq] patched AeroSpace checkout not found or incomplete at $root_dir/AeroSpace"
    echo "[prereq] Run ./utils/refresh-workspace.sh first."
    exit 1
fi

mkdir -p "$log_dir"
register_cleanup_path "$fake_install_root" "$test_home"
trap cleanup_paths_on_exit EXIT
mkdir -p "$fake_install_root/libexec"
cp -R "$runtime_src" "$fake_runtime_dir"
cp -R "$root_dir/devutils" "$fake_install_root/devutils"
cp -R "$root_dir/configs" "$fake_install_root/configs"
cp -R "$root_dir/gfx" "$fake_install_root/gfx"
chmod +x "$fake_install_root/devutils/setup-wallpaper.sh"
mkdir -p "$fake_install_root/AeroSpace/docs"
cp -R "$root_dir/AeroSpace/docs/config-examples" "$fake_install_root/AeroSpace/docs/config-examples"

exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] fake_runtime_dir=$fake_runtime_dir"
echo "[info] test_home=$test_home"
echo "[info] log_file=$log_file"

echo "[step] running the init runtime in default-apply mode"
HYPRSPACE_HOME_OVERRIDE="$test_home" \
    HYPRSPACE_SKIP_DEPENDENCY_SETUP=1 \
    HYPRSPACE_SKIP_MACOS_DEFAULTS=1 \
    HYPRSPACE_SKIP_SKETCHYBAR_SERVICE=1 \
    HYPRSPACE_SKIP_WALLPAPER_SETUP=1 \
    HYPRSPACE_INIT_ASSUME_DEFAULTS=1 \
    bash "$fake_runtime_dir/hyprspace-init"

echo "[step] asserting first-run outputs from the interactive flow"
test -f "$test_home/.config/hyprspace/config.toml"
test -f "$test_home/.config/hyprspace/docs/default-config.toml"
test -f "$test_home/.config/hyprspace/docs/README.md"
test -f "$test_home/.config/hyprspace/docs/ACKNOWLEDGMENTS.md"
test -f "$test_home/.config/sketchybar/sketchybarrc"
grep -q "new-window-or-open Ghostty" "$test_home/.config/hyprspace/config.toml"
grep -q "new-window-or-open Safari" "$test_home/.config/hyprspace/config.toml"
grep -q "new-window-or-open Music" "$test_home/.config/hyprspace/config.toml"
grep -q "active config Hyprspace loads" "$test_home/.config/hyprspace/docs/README.md"
grep -q "sketchybar --trigger hyprspace_workspace_change" "$test_home/.config/hyprspace/config.toml"
grep -q "borders active_color=" "$test_home/.config/hyprspace/config.toml"

echo "[ok] hyprspace interactive smoke test passed"
