#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
source "$root_dir/tests/_common.sh"

checkout_dir="$root_dir/AeroSpace"

echo "[info] root_dir=$root_dir"
echo "[info] checkout_dir=$checkout_dir"

if [[ ! -d "$checkout_dir" ]]; then
    echo "[prereq] patched AeroSpace checkout not found at $checkout_dir"
    echo "[prereq] Run: mise run patch:refresh-workspace"
    exit 1
fi

# versionGenerated.swift and friends are produced by generate.sh, not by swift
# build, so a freshly refreshed workspace will not compile without this.
echo "[step] generating derived sources"
(cd "$checkout_dir" && ./generate.sh >/dev/null)

echo "[step] running swift test"
(cd "$checkout_dir" && swift test)

echo "[ok] hyprspace swift unit test passed"
