#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
source "$root_dir/tests/_common.sh"

log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-public-surface-docs.log"
generated_cask="$root_dir/AeroSpace/.release/hyprspace.rb"
tap_repo="$root_dir/../../brew"
releases_repo="$root_dir/../hyprspace-releases"

mkdir -p "$log_dir"
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] generated_cask=$generated_cask"
echo "[info] tap_repo=$tap_repo"
echo "[info] releases_repo=$releases_repo"
echo "[info] log_file=$log_file"

require_cmd python3

if [[ ! -f "$generated_cask" ]]; then
    echo "[prereq] missing generated cask at $generated_cask"
    echo "[prereq] Run RUN_INTEGRATION_TESTS=1 bash tests/test-hyprspace-release-build.sh first."
    exit 1
fi

echo "[step] syncing and validating local public surface sync"
python3 "$root_dir/scripts/internal/validate-public-release-surface.py" --phase local-sync

echo "[step] showing tap README legal/release links"
grep -nE 'hyprspace-releases|LEGAL|LICENSE' "$tap_repo/README.md"

echo "[step] checking generated local release notes surface"
test -f "$root_dir/AeroSpace/.release/release-notes.md"
grep -nE 'brew install --cask hyprspace|LEGAL.md|LICENSE|not code-signed|notarized' "$root_dir/AeroSpace/.release/release-notes.md"

echo "[step] checking generated cask public homepage assertions"
grep -n 'homepage "https://hyprspace.net/"' "$generated_cask"
grep -n 'verified: "github.com/PeachlifeAB/hyprspace-releases/"' "$generated_cask"
if grep -n 'homepage "https://github.com/PeachlifeAB/hyprspace-core"' "$generated_cask"; then
    echo "[error] generated cask still points at private source repo"
    exit 1
fi
if grep -n 'homepage "https://github.com/PeachlifeAB/hyprspace-releases"' "$generated_cask"; then
    echo "[error] generated cask still uses releases repo as homepage"
    exit 1
fi

echo "[step] showing releases repo root docs"
ls -l "$releases_repo"
test -f "$releases_repo/README.md"
test -f "$releases_repo/LEGAL.md"
test -f "$releases_repo/LICENSE"
cmp "$root_dir/LICENSE" "$releases_repo/LICENSE"

echo "[ok] hyprspace public surface docs test passed"
