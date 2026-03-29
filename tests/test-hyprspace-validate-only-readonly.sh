#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
source "$root_dir/tests/_common.sh"
source "$root_dir/script/repo-state-table.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
validate_only_readonly_on_exit() {
    print_repo_state_table validate-only-readonly-final \
        source "$root_dir" \
        tap "$tap_repo" \
        releases "$releases_repo"
}

require_opt_in RUN_INTEGRATION_TESTS "test-hyprspace-validate-only-readonly.sh is in the integration tier."

log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-validate-only-readonly.log"
tap_repo="$root_dir/../homebrew-hyprspace"
releases_repo="$root_dir/../hyprspace-releases"
trap validate_only_readonly_on_exit EXIT

mkdir -p "$log_dir"
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] tap_repo=$tap_repo"
echo "[info] releases_repo=$releases_repo"
echo "[info] log_file=$log_file"
print_repo_state_table validate-only-readonly-preflight \
    source "$root_dir" \
    tap "$tap_repo" \
    releases "$releases_repo"

before_source="$(git -C "$root_dir" status --short)"
before_tap="$(git -C "$tap_repo" status --short)"
before_releases="$(git -C "$releases_repo" status --short)"

echo "[step] status before validate-only"
printf '[source-before]\n%s\n' "${before_source:-<clean>}"
printf '[tap-before]\n%s\n' "${before_tap:-<clean>}"
printf '[releases-before]\n%s\n' "${before_releases:-<clean>}"

echo "[step] running validate-only"
bash "$root_dir/script/publish-hyprspace-release.sh" --validate-only

after_source="$(git -C "$root_dir" status --short)"
after_tap="$(git -C "$tap_repo" status --short)"
after_releases="$(git -C "$releases_repo" status --short)"

echo "[step] status after validate-only"
printf '[source-after]\n%s\n' "${after_source:-<clean>}"
printf '[tap-after]\n%s\n' "${after_tap:-<clean>}"
printf '[releases-after]\n%s\n' "${after_releases:-<clean>}"

test "$before_source" = "$after_source"
test "$before_tap" = "$after_tap"
test "$before_releases" = "$after_releases"

echo "[ok] validate-only preserved tracked repo state"
