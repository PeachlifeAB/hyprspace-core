#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
source "$root_dir/tests/_common.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()

log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-publish-remote-guard.log"
workspace_root="$(make_temp_dir)"
source_repo="$workspace_root/hyprspace-core"
tap_repo="$workspace_root/brew"
releases_repo="$workspace_root/hyprspace-releases"
tap_remote="$workspace_root/brew-remote.git"

mkdir -p "$log_dir"
register_cleanup_path "$workspace_root"
trap cleanup_paths_on_exit EXIT
exec > >(tee "$log_file") 2>&1

cp -R "$root_dir" "$source_repo"
mkdir -p "$tap_repo/Casks" "$releases_repo"

rm -rf "$source_repo/.git"
git -C "$source_repo" init -b main >/dev/null 2>&1
git -C "$source_repo" add .
git -C "$source_repo" -c user.name='Test' -c user.email='test@example.com' commit -m 'init source' >/dev/null

git -C "$tap_repo" init -b main >/dev/null 2>&1
git -C "$releases_repo" init -b main >/dev/null 2>&1
git init --bare "$tap_remote" >/dev/null 2>&1
git -C "$tap_repo" remote add origin "$tap_remote"
git -C "$releases_repo" remote add origin git@github.com:PeachlifeAB/hyprspace-releases.git

printf '%s\n' '# tap' >"$tap_repo/README.md"
printf '%s\n' 'class Hyprspace < Cask; end' >"$tap_repo/Casks/hyprspace.rb"
git -C "$tap_repo" add README.md Casks/hyprspace.rb
git -C "$tap_repo" -c user.name='Test' -c user.email='test@example.com' commit -m 'init tap' >/dev/null
git -C "$tap_repo" push -u origin main >/dev/null 2>&1

printf '%s\n' '# releases' >"$releases_repo/README.md"
printf '%s\n' 'legal' >"$releases_repo/LEGAL.md"
printf '%s\n' 'license' >"$releases_repo/LICENSE"
git -C "$releases_repo" add README.md LEGAL.md LICENSE
git -C "$releases_repo" -c user.name='Test' -c user.email='test@example.com' commit -m 'init releases' >/dev/null

echo "[step] run publish with missing upstream tracking"
set +e
output="$(bash "$source_repo/scripts/release/publish-hyprspace-release.sh" 0.1.3 2>&1)"
status=$?
set -e
printf '%s\n' "$output"

test "$status" -ne 0 || die "[fail] publish unexpectedly succeeded"
grep -q "releases repo branch 'main' has no upstream" <<<"$output" || die "[fail] missing explicit upstream guard message"

latest_publish_log="$(ls -t "$source_repo"/log/release/*-publish-hyprspace-release.log 2>/dev/null | head -n 1)"
test -n "$latest_publish_log" || die "[fail] publish log was not created"
echo "[info] latest_publish_log=$latest_publish_log"

echo "[ok] publish remote guard test passed"
