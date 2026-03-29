#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
checkout_dir="$root_dir/AeroSpace"
log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-cli-identity.log"

mkdir -p "$log_dir"
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] checkout_dir=$checkout_dir"
echo "[info] log_file=$log_file"

if [[ ! -d "$checkout_dir" ]]; then
    echo "[prereq] patched AeroSpace checkout not found at $checkout_dir"
    echo "[prereq] Run ./scripts/patch/refresh-workspace.sh first."
    exit 1
fi

cd "$checkout_dir"

expected_base_version="$(cat "$root_dir/aerospace_version.txt")"
expected_hash="hyprspace-test-hash"
expected_product_version="$(cat "$root_dir/version.txt")-$expected_hash"
expected_display_version="Hyprspace v${expected_product_version} (AeroSpace ${expected_base_version})"

echo "[step] expected_base_version=$expected_base_version"
echo "[step] expected_product_version=$expected_product_version"
echo "[step] expected_hash=$expected_hash"
echo "[step] running generate.sh"
HYPRSPACE_GIT_HASH="$expected_hash" ./generate.sh --generate-git-hash --ignore-xcodeproj --ignore-shell-parser

echo "[step] running swift run hyprspace --version"
if ! output="$(swift run hyprspace --version 2>&1)"; then
    echo "[error] swift run hyprspace --version failed"
    printf '%s\n' "$output"
    exit 1
fi

echo "[step] command output follows"
printf '%s\n' "$output"
actual_output="$(printf '%s\n' "$output" | tail -n 1)"
test "$actual_output" = "$expected_display_version"
echo "[ok] hyprspace CLI identity test passed"
