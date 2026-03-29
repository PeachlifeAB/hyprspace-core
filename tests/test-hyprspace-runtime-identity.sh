#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
checkout_dir="$root_dir/AeroSpace"
log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-runtime-identity.log"

cleanup() {
    rm -f "$checkout_dir"/*-2.d "$checkout_dir"/*-2.dia "$checkout_dir"/*-2.swiftdeps "$checkout_dir"/*-2.swiftmodule
}
trap cleanup EXIT

mkdir -p "$log_dir"
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] checkout_dir=$checkout_dir"
echo "[info] log_file=$log_file"

if [[ ! -d "$checkout_dir" ]]; then
    echo "[prereq] patched AeroSpace checkout not found at $checkout_dir"
    echo "[prereq] Run ./utils/refresh-workspace.sh first."
    exit 1
fi

cd "$checkout_dir"

echo "[step] running swift test filter HyprspaceIdentityTest"
swift test --filter HyprspaceIdentityTest
