#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
runtime_dir="$root_dir/libexec/hyprspace-init"
log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-init-defaults.log"

mkdir -p "$log_dir"
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] runtime_dir=$runtime_dir"
echo "[info] log_file=$log_file"

echo "[step] asking wizard runtime for default selection payload"
output="$(cd /tmp && HYPRSPACE_INIT_TEST_MODE=defaults bash "$runtime_dir/hyprspace-init")"

echo "[step] command output follows"
printf '%s\n' "$output"
HYPRSPACE_INIT_DEFAULTS_JSON="$output" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["HYPRSPACE_INIT_DEFAULTS_JSON"])
assert payload["selected_optional_steps"] == [
    "sketchybar",
    "borders",
    "macos_defaults",
    "wallpaper",
    "btop",
]
assert payload["mandatory_steps"] == ["hyprspace_config", "hack_nerd_font"]
assert payload["terminal_app"] == "Ghostty"
assert payload["music_app"] == "Apple Music"
assert payload["browser_app"] == "Safari"
assert payload["apply_flags"] == []
PY

echo "[ok] hyprspace init defaults test passed"
