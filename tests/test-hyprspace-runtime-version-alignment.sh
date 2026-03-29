#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
checkout_dir="$root_dir/AeroSpace"
source "$root_dir/tests/_common.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
require_opt_in RUN_INTEGRATION_TESTS "test-hyprspace-runtime-version-alignment.sh is in the integration tier."
log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-runtime-version-alignment.log"
release_cli="$checkout_dir/.release/hyprspace"
release_app="$checkout_dir/.release/Hyprspace.app"

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

if [[ ! -f "$release_cli" || ! -d "$release_app" ]]; then
    echo "[prereq] built release artifacts not found (.release/hyprspace or .release/Hyprspace.app)"
    echo "[prereq] Run: bash tests/test-hyprspace-release-build.sh"
    exit 1
fi

echo "[step] checking fresh release artifact versions"
hyprspace_assert_release_artifact_versions "$release_cli" "$release_app"

if pgrep -x Hyprspace >/dev/null 2>&1; then
    echo "[step] checking live runtime alignment against installed Hyprspace"
    hyprspace_assert_live_runtime_version_alignment "$release_cli" "$release_app"
else
    echo "[info] live Hyprspace.app not running; installed runtime alignment not required for this preflight"
fi

echo "[ok] hyprspace runtime version alignment preflight passed"
