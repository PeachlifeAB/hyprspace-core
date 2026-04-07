#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
source "$root_dir/tests/_common.sh"
source "$root_dir/product.conf"
source "$root_dir/scripts/verify/repo-state-table.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
public_smoke_on_exit() {
    print_public_install_artifact_state exit "$build_version"
    print_home_config_state public-smoke-home-exit "$public_init_home"
    print_repo_state_table public-smoke-final \
        source "$root_dir" \
        tap "$root_dir/../../brew" \
        releases "$root_dir/../hyprspace-releases"
    cleanup_paths_on_exit
}

if [[ "${RUN_PUBLIC_RELEASE_SMOKE:-0}" != "1" ]]; then
    echo "[error] RUN_PUBLIC_RELEASE_SMOKE=1 is required for test-hyprspace-public-release-smoke.sh" >&2
    exit 1
fi

log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-public-release-smoke.log"
build_version="$(tr -d '\r' <"$root_dir/version.txt")"
tag="${HYPRSPACE_TAG_PREFIX}${build_version}"
tap_readme_url="https://raw.githubusercontent.com/${HYPRSPACE_TAP_REPO}/main/README.md"
releases_root_url="https://raw.githubusercontent.com/${HYPRSPACE_RELEASES_REPO}/main"

public_test_home="$(make_temp_dir)"
public_init_home="$(make_temp_dir)"
register_cleanup_path "$public_test_home" "$public_init_home"
trap public_smoke_on_exit EXIT

mkdir -p "$log_dir"
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] build_version=$build_version"
echo "[info] tag=$tag"
echo "[info] tap_readme_url=$tap_readme_url"
echo "[info] log_file=$log_file"
print_repo_state_table public-smoke-preflight \
    source "$root_dir" \
    tap "$root_dir/../../brew" \
    releases "$root_dir/../hyprspace-releases"
print_public_install_artifact_state pre-install "$build_version"
print_home_config_state public-smoke-home-pre "$public_init_home"

require_cmd brew
require_cmd curl

echo "[step] fetching public tap README, release README, LEGAL, and LICENSE"
curl -fsSL "$tap_readme_url" >/tmp/hyprspace-tap-readme.txt
curl -fsSL "$releases_root_url/README.md" >/tmp/hyprspace-release-readme.txt
curl -fsSL "$releases_root_url/LEGAL.md" >/tmp/hyprspace-release-legal.txt
curl -fsSL "$releases_root_url/LICENSE" >/tmp/hyprspace-release-license.txt
head -n 5 /tmp/hyprspace-tap-readme.txt
head -n 5 /tmp/hyprspace-release-readme.txt
head -n 5 /tmp/hyprspace-release-legal.txt
head -n 5 /tmp/hyprspace-release-license.txt

echo "[step] checking public release surface links"
grep -nE 'LEGAL|LICENSE|hyprspace-releases' /tmp/hyprspace-tap-readme.txt

echo "[step] installing public Homebrew cask"
brew uninstall --cask --force hyprspace >/dev/null 2>&1 || true
brew untap PeachlifeAB/hyprspace >/dev/null 2>&1 || true
HOMEBREW_NO_INSTALL_FROM_API=1 brew tap PeachlifeAB/hyprspace
HOMEBREW_NO_INSTALL_FROM_API=1 brew install --cask --force hyprspace
print_public_install_artifact_state post-install "$build_version"

echo "[step] asserting installed public artifacts"
test -d /Applications/Hyprspace.app
nested_cli="/opt/homebrew/Caskroom/hyprspace/${build_version}/Hyprspace-v${build_version}/libexec/hyprspace-cli"
packaged_init="/opt/homebrew/Caskroom/hyprspace/${build_version}/Hyprspace-v${build_version}/libexec/hyprspace-init/hyprspace-init"
packaged_notify_helper="/opt/homebrew/Caskroom/hyprspace/${build_version}/Hyprspace-v${build_version}/libexec/hyprspace-init/hyprspace-notify-menubar"
packaged_wallpaper_helper="/opt/homebrew/Caskroom/hyprspace/${build_version}/Hyprspace-v${build_version}/libexec/hyprspace-init/hyprspace-set-wallpaper"
test -x "$nested_cli"
test -x "$packaged_init"
test -x "$packaged_notify_helper"
test -x "$packaged_wallpaper_helper"
echo "[info] nested_cli=$nested_cli"
echo "[info] packaged_init=$packaged_init"
xattr -l "$nested_cli" 2>/dev/null || true
if xattr -p com.apple.quarantine "$nested_cli" >/dev/null 2>&1; then
    echo "[error] nested CLI remains quarantined: $nested_cli" >&2
    exit 1
fi
output="$(hyprspace --version 2>&1 | tr -d '\r')"
printf '%s\n' "$output"
test "$output" = "Hyprspace v${build_version}"

echo "[step] running public hyprspace init"
init_output="$(HYPRSPACE_HOME_OVERRIDE="$public_init_home" HYPRSPACE_SKIP_DEPENDENCY_SETUP=1 HYPRSPACE_SKIP_MACOS_DEFAULTS=1 HYPRSPACE_SKIP_SKETCHYBAR_SERVICE=1 HYPRSPACE_SKIP_WALLPAPER_SETUP=1 HYPRSPACE_INIT_ASSUME_DEFAULTS=1 script -q /dev/null hyprspace init 2>&1)"
printf '%s\n' "$init_output"
print_home_config_state public-smoke-home-post-init "$public_init_home"
test -f "$public_init_home/.config/hyprspace/config.toml"
test -f "$public_init_home/.config/hyprspace/docs/default-config.toml"
test -f "$public_init_home/.config/hyprspace/docs/README.md"
test -f "$public_init_home/.config/hyprspace/docs/ACKNOWLEDGMENTS.md"
test -f "$public_init_home/.config/sketchybar/sketchybarrc"

echo "[ok] hyprspace public release smoke passed"
