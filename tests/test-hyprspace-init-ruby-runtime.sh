#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
runtime_src="$root_dir/libexec/hyprspace-init"
source "$root_dir/tests/_common.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
fake_install_root="$(make_temp_dir)"
fake_runtime_dir="$fake_install_root/libexec/hyprspace-init"
log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-init-runtime.log"

mkdir -p "$log_dir"
register_cleanup_path "$fake_install_root"
trap cleanup_paths_on_exit EXIT
mkdir -p "$fake_install_root/libexec"
cp -R "$runtime_src" "$fake_runtime_dir"

exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] fake_runtime_dir=$fake_runtime_dir"
echo "[info] log_file=$log_file"

echo "[step] running shell init entrypoint in test mode from fake installed layout"
output="$(cd /tmp && HYPRSPACE_INIT_TEST_MODE=1 bash "$fake_runtime_dir/hyprspace-init")"

echo "[step] command output follows"
printf '%s\n' "$output"
grep -q '"runtime_root":' <<<"$output"
grep -q '"apply_script_exists": true' <<<"$output"
grep -q '"apply_script": .*apply-init-selections.sh' <<<"$output"

echo "[ok] hyprspace init runtime test passed"
