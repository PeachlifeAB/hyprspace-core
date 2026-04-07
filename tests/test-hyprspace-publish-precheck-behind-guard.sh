#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
source "$root_dir/tests/_common.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()

log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-publish-pre-release-checks-behind-guard.log"
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
mkdir -p "$releases_repo"

rm -rf "$source_repo/.git"
git -C "$source_repo" init -b main >/dev/null 2>&1
git -C "$source_repo" add .
git -C "$source_repo" -c user.name='Test' -c user.email='test@example.com' commit -m 'init source' >/dev/null
git -C "$source_repo" remote add origin "$source_repo"

git init --bare "$tap_remote" >/dev/null 2>&1
git clone "$tap_remote" "$tap_repo" >/dev/null 2>&1
git -C "$tap_repo" checkout -b main >/dev/null 2>&1
printf '%s\n' '# tap' >"$tap_repo/README.md"
mkdir -p "$tap_repo/Casks"
printf '%s\n' 'class Hyprspace < Cask; end' >"$tap_repo/Casks/hyprspace.rb"
git -C "$tap_repo" add README.md Casks/hyprspace.rb
git -C "$tap_repo" -c user.name='Test' -c user.email='test@example.com' commit -m 'init tap' >/dev/null
git -C "$tap_repo" push -u origin main >/dev/null 2>&1

git -C "$releases_repo" init -b main >/dev/null 2>&1
git -C "$releases_repo" remote add origin "$releases_repo"
printf '%s\n' '# releases' >"$releases_repo/README.md"
printf '%s\n' 'legal' >"$releases_repo/LEGAL.md"
printf '%s\n' 'license' >"$releases_repo/LICENSE"
git -C "$releases_repo" add README.md LEGAL.md LICENSE
git -C "$releases_repo" -c user.name='Test' -c user.email='test@example.com' commit -m 'init releases' >/dev/null
git -C "$releases_repo" push -u origin main >/dev/null 2>&1

echo "[step] advance remote tap so local tap is behind"
remote_worktree="$workspace_root/brew-remote-worktree"
git clone "$tap_remote" "$remote_worktree" >/dev/null 2>&1
printf '%s\n' '# tap updated remotely' >"$remote_worktree/README.md"
git -C "$remote_worktree" add README.md
git -C "$remote_worktree" -c user.name='Test' -c user.email='test@example.com' commit -m 'remote update' >/dev/null
git -C "$remote_worktree" push origin main >/dev/null 2>&1

echo "[step] run publish pre-release-checks with behind tap repo"
set +e
output="$(bash "$source_repo/scripts/release/pre-release-checks.sh" 0.1.3 2>&1)"
status=$?
set -e
printf '%s\n' "$output"

test "$status" -ne 0 || die "[fail] publish pre-release-checks unexpectedly succeeded"
grep -q "tap repo branch 'main' is behind origin/main by 1 commit(s)" <<<"$output" || die "[fail] missing explicit behind guard message"

echo "[ok] publish pre-release-checks behind guard test passed"
