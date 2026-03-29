#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
runtime_dir="$root_dir/libexec/hyprspace-init"
log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-init-selection-preview.log"

mkdir -p "$log_dir"
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] runtime_dir=$runtime_dir"
echo "[info] log_file=$log_file"

echo "[step] asking wizard runtime for a deselected selection preview"
output="$(cd /tmp && HYPRSPACE_INIT_TEST_MODE=selection-preview HYPRSPACE_INIT_TEST_SELECTIONS='macos_defaults' HYPRSPACE_INIT_TEST_TERMINAL_APP='Terminal.app' HYPRSPACE_INIT_TEST_MUSIC_APP='Spotify' HYPRSPACE_INIT_TEST_BROWSER_APP='Helium' bash "$runtime_dir/hyprspace-init")"

echo "[step] command output follows"
printf '%s\n' "$output"
HYPRSPACE_INIT_SELECTION_JSON="$output" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["HYPRSPACE_INIT_SELECTION_JSON"])
assert payload["selected_optional_steps"] == ["macos_defaults"]
assert payload["mandatory_steps"] == ["hyprspace_config", "hack_nerd_font"]
assert payload["terminal_app"] == "Terminal.app"
assert payload["music_app"] == "Spotify"
assert payload["browser_app"] == "Helium"
assert payload["apply_flags"] == [
    "--without-sketchybar",
    "--without-borders",
    "--without-wallpaper",
]
PY

echo "[ok] hyprspace init selection preview test passed"
