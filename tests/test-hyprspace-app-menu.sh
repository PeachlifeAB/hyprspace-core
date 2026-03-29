#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
checkout_dir="$root_dir/AeroSpace"
source "$root_dir/tests/_common.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
declare -a HYPRSPACE_TEST_TRACKED_APPS=("Hyprspace" "AeroSpace" "Terminal")
require_opt_in RUN_INTEGRATION_TESTS "test-hyprspace-app-menu.sh is in the integration tier."
log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-app-menu.log"
release_cli="$checkout_dir/.release/hyprspace"
release_app="$checkout_dir/.xcode-build/Build/Products/Release/Hyprspace.app"
target_app_name="Terminal"
target_bundle_id="com.apple.Terminal"

hyprspace_ready() {
    "$release_cli" list-workspaces --all >/dev/null 2>&1
}

hyprspace_server_running() {
    pgrep -x Hyprspace >/dev/null 2>&1
}

terminal_window_count() {
    osascript -e 'tell application "Terminal" to count windows'
}

terminal_window_available() {
    test "$(terminal_window_count)" -ge 1
}

terminal_window_increased() {
    test "$(terminal_window_count)" -gt "$before_count"
}

cleanup_test_processes() {
    pkill -x Terminal >/dev/null 2>&1 || true
}

mkdir -p "$log_dir"
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] checkout_dir=$checkout_dir"
echo "[info] log_file=$log_file"
echo "[info] release_cli=$release_cli"
echo "[info] release_app=$release_app"

if [[ ! -d "$checkout_dir" ]]; then
    echo "[prereq] patched AeroSpace checkout not found at $checkout_dir"
    echo "[prereq] Run ./utils/refresh-workspace.sh first."
    exit 1
fi

if [[ ! -f "$release_cli" || ! -d "$release_app" ]]; then
    echo "[prereq] built artifacts not found (.release/hyprspace or .xcode-build app)"
    echo "[prereq] Run: bash tests/test-hyprspace-release-build.sh"
    exit 1
fi

require_no_preexisting_window_manager
require_tracked_apps_not_running
HYPRSPACE_TEST_WINDOW_CLI="$release_cli"
hyprspace_capture_clean_slate_baseline

echo "[step] launching Hyprspace app server"
nohup "$release_app/Contents/MacOS/Hyprspace" >/tmp/hyprspace-app-menu-server.log 2>&1 </dev/null &
HYPRSPACE_PID=$!
trap 'hyprspace_finish_test $? cleanup_test_processes' EXIT INT TERM
wait_until 15 1 hyprspace_server_pid_running
echo "[info] hyprspace_server_pid=$HYPRSPACE_PID"
wait_until 15 1 hyprspace_ready
hyprspace_assert_server_running "post-ready"

echo "[step] launching $target_app_name"
open -a "$target_app_name"
wait_until 15 1 terminal_window_available

echo "[step] counting $target_app_name windows before app-menu command"
before_count="$(osascript -e 'tell application "Terminal" to count windows')"
printf '%s\n' "$before_count"

echo "[step] running app-menu command from release CLI"
hyprspace_assert_server_running "before app-menu"
"$release_cli" app-menu --app-bundle-id "$target_bundle_id" --match-leaf "new window" --click-first

wait_until 15 1 terminal_window_increased

echo "[step] checking $target_app_name window count increased"
after_count="$(osascript -e 'tell application "Terminal" to count windows')"
printf '%s\n' "$after_count"
test "$after_count" -gt "$before_count"

echo "[ok] hyprspace app-menu command succeeded"
