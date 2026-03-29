#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
checkout_dir="$root_dir/AeroSpace"
source "$root_dir/tests/_common.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-init-required.log"
test_home="$(make_temp_dir)"

mkdir -p "$log_dir"
register_cleanup_path "$test_home"
trap cleanup_paths_on_exit EXIT
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] checkout_dir=$checkout_dir"
echo "[info] test_home=$test_home"
echo "[info] log_file=$log_file"

if [[ ! -f "$checkout_dir/docs/config-examples/default-config.toml" ]]; then
    echo "[prereq] patched AeroSpace checkout not found or incomplete at $checkout_dir"
    echo "[prereq] Run ./scripts/patch/refresh-workspace.sh first."
    exit 1
fi

cd "$checkout_dir"

echo "[step] running generate.sh"
HYPRSPACE_GIT_HASH="hyprspace-init-test-hash" ./generate.sh --generate-git-hash --ignore-xcodeproj --ignore-shell-parser

echo "[step] running a non-init command with no user config"
if output="$(HYPRSPACE_HOME_OVERRIDE="$test_home" swift run hyprspace reload-config 2>&1)"; then
    echo "[error] non-init command unexpectedly succeeded without initialization"
    printf '%s\n' "$output"
    exit 1
fi

echo "[step] command output follows"
printf '%s\n' "$output"
grep -q 'run `hyprspace init` first' <<<"$output"

echo "[step] creating a canonical config and re-running"
mkdir -p "$test_home/.config/hyprspace"
cp "$root_dir/AeroSpace/docs/config-examples/default-config.toml" "$test_home/.config/hyprspace/config.toml"

if output="$(HYPRSPACE_HOME_OVERRIDE="$test_home" swift run hyprspace reload-config 2>&1)"; then
    echo "[error] reload-config unexpectedly succeeded without a running server"
    printf '%s\n' "$output"
    exit 1
fi

printf '%s\n' "$output"
grep -q "Can't connect to Hyprspace server" <<<"$output"
echo "[ok] hyprspace init required gate test passed"
