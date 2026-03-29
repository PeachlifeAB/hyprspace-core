#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
checkout_dir="$root_dir/AeroSpace"
source "$root_dir/tests/_common.sh"
source "$root_dir/scripts/verify/repo-state-table.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
local_install_on_exit() {
    print_local_install_artifact_state exit "$install_prefix"
    print_home_config_state local-install-home-exit "$test_home"
    print_home_config_state local-install-init-home-exit "$init_home"
    cleanup_paths_on_exit
}

if [[ "${RUN_INTEGRATION_TESTS:-0}" != "1" ]]; then
    echo "[error] RUN_INTEGRATION_TESTS=1 is required for test-hyprspace-local-install.sh" >&2
    exit 1
fi
log_dir="$root_dir/log/install"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-local-install.log"
install_prefix="$(make_temp_dir)"
test_home="$(make_temp_dir)"
init_home="$(make_temp_dir)"
interactive_home="$(make_temp_dir)"
interactive_fail_home="$(make_temp_dir)"
fake_bin_dir="$(make_temp_dir)"
open_log="$fake_bin_dir/open.log"
launch_marker="$fake_bin_dir/hyprspace.launch.marker"
expected_version="$(cat "$root_dir/version.txt")"
expected_display_version="Hyprspace v${expected_version}"

mkdir -p "$log_dir"
register_cleanup_path "$install_prefix" "$test_home" "$init_home" "$interactive_home" "$interactive_fail_home" "$fake_bin_dir"
trap local_install_on_exit EXIT
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] checkout_dir=$checkout_dir"
echo "[info] install_prefix=$install_prefix"
echo "[info] test_home=$test_home"
echo "[info] log_file=$log_file"
echo "[info] interactive_home=$interactive_home"
echo "[info] interactive_fail_home=$interactive_fail_home"
echo "[info] fake_bin_dir=$fake_bin_dir"
print_local_install_artifact_state pre-install "$install_prefix"
print_home_config_state local-install-home-pre "$test_home"
print_home_config_state local-install-init-home-pre "$init_home"
print_home_config_state local-install-interactive-home-pre "$interactive_home"
print_home_config_state local-install-interactive-fail-home-pre "$interactive_fail_home"

if [[ ! -d "$checkout_dir" ]]; then
    echo "[prereq] patched AeroSpace checkout not found at $checkout_dir"
    echo "[prereq] Run ./scripts/patch/refresh-workspace.sh first."
    exit 1
fi

cd "$checkout_dir"

echo "[step] running install-local.sh in isolated local-prefix mode"
INSTALL_PREFIX="$install_prefix" \
    HYPRSPACE_USE_EXISTING_RELEASE=1 \
    HYPRSPACE_HOME_OVERRIDE="$test_home" \
    HYPRSPACE_SKIP_DEPENDENCY_SETUP=1 \
    HYPRSPACE_SKIP_MACOS_DEFAULTS=1 \
    HYPRSPACE_SKIP_SKETCHYBAR_SERVICE=1 \
    HYPRSPACE_SKIP_WALLPAPER_SETUP=1 \
    "$root_dir/scripts/install/install-local.sh"
print_local_install_artifact_state post-install "$install_prefix"
print_home_config_state local-install-home-post-install "$test_home"

echo "[step] asserting installed artifacts"
test -f "$install_prefix/bin/hyprspace"
test -d "$install_prefix/Hyprspace.app"
test -x "$install_prefix/libexec/hyprspace-init/hyprspace-init"
test -f "$install_prefix/libexec/hyprspace-init/apply-init-selections.sh"
test -f "$install_prefix/libexec/hyprspace-init/step-metadata.sh"
test -f "$install_prefix/libexec/hyprspace-init/presentation.sh"
test -f "$install_prefix/scripts/internal/setup-wallpaper.sh"
test -f "$install_prefix/artifacts/gfx/wallpaper-default.jpg"
test -f "$test_home/.config/hyprspace/config.toml"
test -f "$test_home/.config/hyprspace/docs/default-config.toml"
test -f "$test_home/.config/hyprspace/docs/README.md"
test -f "$test_home/.config/hyprspace/docs/ACKNOWLEDGMENTS.md"
test -f "$test_home/.config/sketchybar/sketchybarrc"
test -x "$test_home/.config/sketchybar/plugins/hyprspace_workspace.sh"

echo "[step] running installed hyprspace --version"
output="$($install_prefix/bin/hyprspace --version 2>&1)"
printf '%s\n' "$output"
test "$output" = "$expected_display_version"

cat >"$fake_bin_dir/gum" <<'EOF'
#!/bin/bash
set -euo pipefail

command_name="$1"
shift

case "$command_name" in
style)
    printf '%s\n' "${*: -1}"
    ;;
confirm)
    exit 0
    ;;
choose)
    selected=""
    no_limit=0
    for arg in "$@"; do
        case "$arg" in
        --selected=*) selected="${arg#--selected=}" ;;
        --no-limit) no_limit=1 ;;
        esac
    done
    if [ "$no_limit" -eq 1 ]; then
        OLD_IFS="$IFS"
        IFS=','
        read -r -a values <<< "$selected"
        IFS="$OLD_IFS"
        printf '%s\n' "${values[@]}"
    else
        printf '%s\n' "$selected"
    fi
    ;;
*)
    echo "unexpected gum command: $command_name" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$fake_bin_dir/gum"

cat >"$fake_bin_dir/open" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$@" > "$OPEN_LOG"
if [ "${FAKE_OPEN_MODE:-launch}" = "launch" ]; then
    : > "$LAUNCH_MARKER"
fi
EOF
chmod +x "$fake_bin_dir/open"

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
chmod +x "$fake_bin_dir/pgrep"

echo "[step] running installed hyprspace init from packaged layout"
init_output="$(HYPRSPACE_HOME_OVERRIDE="$init_home" HYPRSPACE_SKIP_DEPENDENCY_SETUP=1 HYPRSPACE_SKIP_MACOS_DEFAULTS=1 HYPRSPACE_SKIP_SKETCHYBAR_SERVICE=1 HYPRSPACE_SKIP_WALLPAPER_SETUP=1 HYPRSPACE_INIT_ASSUME_DEFAULTS=1 script -q /dev/null "$install_prefix/bin/hyprspace" init 2>&1)"
printf '%s\n' "$init_output"
print_home_config_state local-install-init-home-post-init "$init_home"
test -f "$init_home/.config/hyprspace/config.toml"
test -f "$init_home/.config/hyprspace/docs/default-config.toml"
test -f "$init_home/.config/hyprspace/docs/README.md"
test -f "$init_home/.config/hyprspace/docs/ACKNOWLEDGMENTS.md"
test -f "$init_home/.config/sketchybar/sketchybarrc"
grep -q "new-window-or-open Ghostty" "$init_home/.config/hyprspace/config.toml"
grep -q "new-window-or-open Safari" "$init_home/.config/hyprspace/config.toml"
grep -q "new-window-or-open Music" "$init_home/.config/hyprspace/config.toml"
grep -q "sketchybar --trigger hyprspace_workspace_change" "$init_home/.config/hyprspace/config.toml"
grep -q "borders active_color=" "$init_home/.config/hyprspace/config.toml"

echo "[step] running installed hyprspace init interactive path with fake gum/open"
rm -f "$launch_marker"
interactive_output="$(PATH="$fake_bin_dir:$PATH" OPEN_LOG="$open_log" LAUNCH_MARKER="$launch_marker" FAKE_OPEN_MODE=launch HYPRSPACE_HOME_OVERRIDE="$interactive_home" HYPRSPACE_SKIP_DEPENDENCY_SETUP=1 HYPRSPACE_SKIP_MACOS_DEFAULTS=1 HYPRSPACE_SKIP_SKETCHYBAR_SERVICE=1 HYPRSPACE_SKIP_WALLPAPER_SETUP=1 "$install_prefix/bin/hyprspace" init 2>&1)"
printf '%s\n' "$interactive_output"
print_home_config_state local-install-interactive-home-post-init "$interactive_home"
grep -q "Accessibility features under the hood" <<<"$interactive_output"
grep -q "Follow the macOS prompts during setup" <<<"$interactive_output"
grep -q "Hyprspace.app is running" <<<"$interactive_output"
test -f "$interactive_home/.config/hyprspace/config.toml"
test -f "$interactive_home/.config/hyprspace/docs/default-config.toml"
test -f "$interactive_home/.config/hyprspace/docs/README.md"
test -f "$interactive_home/.config/hyprspace/docs/ACKNOWLEDGMENTS.md"
test -f "$interactive_home/.config/sketchybar/sketchybarrc"
test -f "$open_log"
grep -q "$install_prefix/Hyprspace.app" "$open_log"

echo "[step] asserting interactive init fails if launch request never produces a Hyprspace process"
rm -f "$launch_marker"
if failure_output="$(PATH="$fake_bin_dir:$PATH" OPEN_LOG="$open_log" LAUNCH_MARKER="$launch_marker" FAKE_OPEN_MODE=no-launch HYPRSPACE_HOME_OVERRIDE="$interactive_fail_home" HYPRSPACE_SKIP_DEPENDENCY_SETUP=1 HYPRSPACE_SKIP_MACOS_DEFAULTS=1 HYPRSPACE_SKIP_SKETCHYBAR_SERVICE=1 HYPRSPACE_SKIP_WALLPAPER_SETUP=1 "$install_prefix/bin/hyprspace" init 2>&1)"; then
    echo "[error] interactive init unexpectedly succeeded without a launched Hyprspace process"
    printf '%s\n' "$failure_output"
    exit 1
fi
printf '%s\n' "$failure_output"
print_home_config_state local-install-interactive-fail-home-post-init "$interactive_fail_home"
grep -q "ERROR: Hyprspace.app launch did not produce a running Hyprspace process" <<<"$failure_output"
if grep -q "Hyprspace.app is running" <<<"$failure_output"; then
    echo "[error] interactive init claimed Hyprspace.app is running despite failed launch verification"
    exit 1
fi

echo "[ok] hyprspace local install test passed"
