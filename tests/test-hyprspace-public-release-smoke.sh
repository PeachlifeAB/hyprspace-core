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
        tap "$root_dir/../../homebrew-tap" \
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
fake_bin_dir="$(make_temp_dir)"
open_log="$fake_bin_dir/open.log"
launch_marker="$fake_bin_dir/hyprspace.launch.marker"
register_cleanup_path "$public_test_home" "$public_init_home" "$fake_bin_dir"
trap public_smoke_on_exit EXIT

mkdir -p "$log_dir"
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] build_version=$build_version"
echo "[info] tag=$tag"
echo "[info] tap_readme_url=$tap_readme_url"
echo "[info] log_file=$log_file"
echo "[info] fake_bin_dir=$fake_bin_dir"
print_repo_state_table public-smoke-preflight \
    source "$root_dir" \
    tap "$root_dir/../../homebrew-tap" \
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

# Force the local tap to match the remote. brew untap may fail if other
# formulae from this tap are installed, and brew tap is a no-op when the
# tap directory already exists. Fetch + reset guarantees the tapped cask
# reflects what was just pushed.
tap_dir="$(brew --repository peachlifeab/tap 2>/dev/null || true)"
if [[ -d "$tap_dir/.git" ]]; then
    echo "[info] updating existing tap at $tap_dir"
    git -C "$tap_dir" fetch origin
    git -C "$tap_dir" reset --hard origin/main
else
    brew untap PeachlifeAB/tap >/dev/null 2>&1 || true
    HOMEBREW_NO_INSTALL_FROM_API=1 brew tap PeachlifeAB/tap
    tap_dir="$(brew --repository peachlifeab/tap)"
fi

# Assert the tapped cask version matches before installing
tapped_version="$(grep -m1 'version "' "$tap_dir/Casks/hyprspace.rb" | sed 's/.*version "//;s/"//')"
if [[ "$tapped_version" != "$build_version" ]]; then
    echo "[error] tapped cask version ($tapped_version) does not match release version ($build_version)" >&2
    echo "[error] tap_dir=$tap_dir" >&2
    git -C "$tap_dir" log --oneline -3 >&2
    exit 1
fi

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

cat >"$fake_bin_dir/open" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$@" > "$OPEN_LOG"
: > "$LAUNCH_MARKER"
EOF
cat >"$fake_bin_dir/pgrep" <<'EOF'
#!/bin/bash
set -euo pipefail
if [ "${1:-}" = "-x" ] && [ "${2:-}" = "Hyprspace" ]; then
    if [ -f "$LAUNCH_MARKER" ]; then
        printf '424242\n'
        exit 0
    fi
    exit 1
fi
exec /usr/bin/pgrep "$@"
EOF
cat >"$fake_bin_dir/sketchybar" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'sketchybar %s\n' "$*" >> "$OPEN_LOG"
EOF
chmod +x "$fake_bin_dir/open" "$fake_bin_dir/pgrep" "$fake_bin_dir/sketchybar"

echo "[step] running public hyprspace init"
rm -f "$launch_marker"
init_output="$(PATH="$fake_bin_dir:$PATH" OPEN_LOG="$open_log" LAUNCH_MARKER="$launch_marker" HYPRSPACE_HOME_OVERRIDE="$public_init_home" HYPRSPACE_SKIP_DEPENDENCY_SETUP=1 HYPRSPACE_SKIP_MACOS_DEFAULTS=1 HYPRSPACE_SKIP_SKETCHYBAR_SERVICE=1 HYPRSPACE_SKIP_WALLPAPER_SETUP=1 HYPRSPACE_INIT_ASSUME_DEFAULTS=1 script -q /dev/null hyprspace init 2>&1)"
printf '%s\n' "$init_output"
print_home_config_state public-smoke-home-post-init "$public_init_home"
test -f "$public_init_home/.config/hyprspace/config.toml"
test -f "$public_init_home/.config/hyprspace/docs/default-config.toml"
test -f "$public_init_home/.config/hyprspace/docs/README.md"
test -f "$public_init_home/.config/hyprspace/docs/ACKNOWLEDGMENTS.md"
test -f "$public_init_home/.config/sketchybar/sketchybarrc"
test -f "$open_log"
grep -q '^/Applications/Hyprspace\.app$' "$open_log"
grep -q '^sketchybar --reload$' "$open_log"

echo "[ok] hyprspace public release smoke passed"
