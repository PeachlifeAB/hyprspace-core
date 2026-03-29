#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
source "$root_dir/tests/_common.sh"

default_homebrew_prefix() {
    if command -v brew >/dev/null 2>&1; then
        brew --prefix
    elif [ "$(uname -m)" = "arm64" ]; then
        printf '%s\n' "/opt/homebrew"
    else
        printf '%s\n' "/usr/local"
    fi
}

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
declare -a HYPRSPACE_TEST_TRACKED_APPS=("Hyprspace" "AeroSpace")
require_opt_in RUN_DESTRUCTIVE_TESTS "test-hyprspace-real-install.sh is in the destructive tier."

confirmed=false
for arg in "$@"; do
    [ "$arg" = "--yes" ] && confirmed=true
done
if [ "$confirmed" = false ]; then
    echo "⚠️  This script installs to live system paths (/Applications, $(default_homebrew_prefix)/bin)."
    echo "   Pass --yes to confirm and proceed."
    exit 1
fi

checkout_dir="$root_dir/AeroSpace"
log_dir="$root_dir/log/install"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-real-install.log"
expected_hash="$(git -C "$root_dir" rev-parse --short HEAD)"
expected_version="$(cat "$root_dir/version.txt")-$expected_hash"
expected_base_version="$(cat "$root_dir/aerospace_version.txt")"
expected_display_version="Hyprspace v${expected_version} (AeroSpace ${expected_base_version})"

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

require_no_preexisting_window_manager

cd "$checkout_dir"

echo "[step] running real install-local.sh"
"$root_dir/scripts/install/install-local.sh"

echo "[step] checking CLI on PATH"
export PATH="$(default_homebrew_prefix)/bin:$PATH"
which hyprspace
cli_output="$(hyprspace --version 2>&1)"
printf '%s\n' "$cli_output"
test "$cli_output" = "$expected_display_version"

echo "[step] checking app install"
test -d /Applications/Hyprspace.app
app_version="$(defaults read /Applications/Hyprspace.app/Contents/Info CFBundleShortVersionString)"
echo "[info] app_version=$app_version"
test "$app_version" = "$expected_version"

echo "[ok] hyprspace real install test passed"
