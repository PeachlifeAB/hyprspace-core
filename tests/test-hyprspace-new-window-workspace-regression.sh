#!/bin/bash
# Regression test for: new-window-or-open should open new windows on the CURRENT workspace
# when the app is already running on a DIFFERENT workspace.
#
# Bug: When an app has a window on workspace 2 and user is on workspace 4,
# triggering new-window-or-open opens the new window on workspace 2 instead of workspace 4.
#
# Root cause: activateAppAndCollectMenuLeaves() activates the app before the menu action,
# which changes focus.workspace before the new window is registered.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
checkout_dir="$root_dir/AeroSpace"
source "$root_dir/tests/_common.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
declare -a HYPRSPACE_TEST_TRACKED_APPS=("Hyprspace" "AeroSpace" "Terminal")
require_opt_in RUN_INTEGRATION_TESTS "test-hyprspace-new-window-workspace-regression.sh is in the integration tier."
log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-new-window-workspace-regression.log"
release_cli="$checkout_dir/.release/hyprspace"
release_app="$checkout_dir/.release/Hyprspace.app"
target_app_name="Terminal"
target_cli_app="Terminal.app"
target_bundle_id="com.apple.Terminal"

hyprspace_ready() {
    "$release_cli" list-workspaces --all >/dev/null 2>&1
}

focused_workspace_is() {
    test "$("$release_cli" list-workspaces --focused --format '%{workspace}' 2>/dev/null | head -1 | tr -d '[:space:]' || echo "")" = "$1"
}

terminal_windows_on_workspace_at_least() {
    local workspace="$1"
    local minimum="$2"
    local count
    count=$("$release_cli" list-windows --workspace "$workspace" --app-bundle-id "$target_bundle_id" --count 2>/dev/null | tr -d '[:space:]' || echo "0")
    test "$count" -ge "$minimum"
}

terminal_windows_on_workspace_greater_than() {
    local workspace="$1"
    local baseline="$2"
    local count
    count=$("$release_cli" list-windows --workspace "$workspace" --app-bundle-id "$target_bundle_id" --count 2>/dev/null | tr -d '[:space:]' || echo "0")
    test "$count" -gt "$baseline"
}

read_workspace_list() {
    "$release_cli" list-workspaces --all 2>/dev/null
}

read_focused_workspace() {
    "$release_cli" list-workspaces --focused --format '%{workspace}' 2>/dev/null | head -1 | tr -d '[:space:]' || echo ""
}

terminal_windows_on_workspace_count() {
    local workspace="$1"
    "$release_cli" list-windows --workspace "$workspace" --app-bundle-id "$target_bundle_id" --count 2>/dev/null | tr -d '[:space:]' || echo "0"
}

log_runtime_state_sample() {
    local label="$1"
    local focused_workspace
    local workspace_list
    local source_count="n/a"
    local target_count="n/a"
    local terminal_processes

    focused_workspace="$(read_focused_workspace)"
    workspace_list="$(read_workspace_list | paste -sd ' ' -)"
    if [[ -n "${SOURCE_WORKSPACE:-}" ]]; then
        source_count="$(terminal_windows_on_workspace_count "$SOURCE_WORKSPACE")"
    fi
    if [[ -n "${TARGET_WORKSPACE:-}" ]]; then
        target_count="$(terminal_windows_on_workspace_count "$TARGET_WORKSPACE")"
    fi
    terminal_processes="$(pgrep -x Terminal | wc -l | tr -d '[:space:]')"

    echo "[monitor] label=$label focused=${focused_workspace:-<none>} workspaces=${workspace_list:-<none>} source=${SOURCE_WORKSPACE:-unset}:$source_count target=${TARGET_WORKSPACE:-unset}:$target_count terminal_processes=$terminal_processes"
}

start_state_sampler() {
    local label="$1"
    stop_state_sampler >/dev/null 2>&1 || true
    (
        while true; do
            log_runtime_state_sample "$label"
            sleep 2
        done
    ) &
    STATE_SAMPLER_PID=$!
    echo "[monitor] started label=$label pid=$STATE_SAMPLER_PID"
}

stop_state_sampler() {
    if [[ -n "${STATE_SAMPLER_PID:-}" ]]; then
        kill "$STATE_SAMPLER_PID" >/dev/null 2>&1 || true
        wait "$STATE_SAMPLER_PID" >/dev/null 2>&1 || true
        echo "[monitor] stopped pid=$STATE_SAMPLER_PID"
        STATE_SAMPLER_PID=""
    fi
}

print_workspace_topology() {
    local label="$1"
    local focused_workspace
    local workspace

    echo "[topology] $label"
    focused_workspace=$("$release_cli" list-workspaces --focused --format '%{workspace}' 2>/dev/null | head -1 | tr -d '[:space:]' || echo "")
    echo "[topology] focused=$focused_workspace"
    while IFS= read -r workspace || [[ -n "$workspace" ]]; do
        [[ -n "$workspace" ]] || continue
        echo "[topology] workspace=$workspace"
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ -n "$line" ]]; then
                echo "[topology]   $line"
            else
                echo "[topology]   <empty>"
            fi
        done < <("$release_cli" list-windows --workspace "$workspace" 2>/dev/null)
        if ! "$release_cli" list-windows --workspace "$workspace" 2>/dev/null | grep -q .; then
            echo "[topology]   <empty>"
        fi
    done < <(read_workspace_list)
}

cleanup_test_processes() {
    start_state_sampler "cleanup"
    pkill -x Terminal >/dev/null 2>&1 || true
    wait_until 15 2 bash -lc 'pgrep -x Terminal >/dev/null 2>&1; test $? -ne 0' || true

    if [[ -n "${ORIGINAL_WORKSPACE:-}" ]]; then
        echo "[step] restoring original workspace $ORIGINAL_WORKSPACE"
        "$release_cli" workspace "$ORIGINAL_WORKSPACE" >/dev/null 2>&1 || true
        if ! wait_until 15 2 focused_workspace_is "$ORIGINAL_WORKSPACE"; then
            echo "[fail] cleanup could not restore original workspace $ORIGINAL_WORKSPACE"
        fi
        restored_workspace=$("$release_cli" list-workspaces --focused --format '%{workspace}' 2>/dev/null | head -1 | tr -d '[:space:]' || echo "")
        echo "[info] restored workspace: $restored_workspace"
    fi
    stop_state_sampler
    print_workspace_topology "after cleanup"
}

pick_alternate_workspace() {
    local workspace
    for workspace in "${WORKSPACES_BEFORE[@]:-}"; do
        if [[ "$workspace" != "$ORIGINAL_WORKSPACE" ]]; then
            printf '%s\n' "$workspace"
            return 0
        fi
    done
    return 1
}

mkdir -p "$log_dir"
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] checkout_dir=$checkout_dir"
echo "[info] log_file=$log_file"

if [[ ! -d "$checkout_dir" ]]; then
    echo "[prereq] patched AeroSpace checkout not found at $checkout_dir"
    echo "[prereq] Run ./scripts/patch/refresh-workspace.sh first."
    exit 1
fi

if [[ ! -f "$release_cli" || ! -d "$release_app" ]]; then
    echo "[prereq] built release artifacts not found (.release/hyprspace or .release/Hyprspace.app)"
    echo "[prereq] Run: bash tests/test-hyprspace-release-build.sh"
    exit 1
fi

echo "[step] checking fresh release artifact versions"
hyprspace_assert_release_artifact_versions "$release_cli" "$release_app"

wait_until 15 1 hyprspace_ready
if ! pgrep -x Hyprspace >/dev/null 2>&1; then
    echo "[skip] live Hyprspace.app session is required for this restoration-safe runtime test"
    exit 0
fi

echo "[step] checking live runtime alignment against installed Hyprspace"
hyprspace_assert_live_runtime_version_alignment "$release_cli" "$release_app"

if pgrep -x Terminal >/dev/null 2>&1; then
    echo "[skip] Terminal is already running; refusing to disturb live user state"
    exit 0
fi

HYPRSPACE_TEST_WINDOW_CLI="$release_cli"
hyprspace_capture_clean_slate_baseline
trap 'hyprspace_finish_test $? cleanup_test_processes' EXIT INT TERM

WORKSPACES_BEFORE=()
while IFS= read -r workspace || [[ -n "$workspace" ]]; do
    [[ -n "$workspace" ]] || continue
    WORKSPACES_BEFORE+=("$workspace")
done < <("$release_cli" list-workspaces --all 2>/dev/null)

ORIGINAL_WORKSPACE=$("$release_cli" list-workspaces --focused --format '%{workspace}' 2>/dev/null | head -1 | tr -d '[:space:]' || echo "")
echo "[info] original workspace: $ORIGINAL_WORKSPACE"
printf '%s\n' "[info] workspaces before: ${WORKSPACES_BEFORE[*]}"
print_workspace_topology "before mutation"

if [[ "${#WORKSPACES_BEFORE[@]}" -lt 2 ]]; then
    echo "[skip] need at least two existing workspaces to run this test without mutating workspace topology"
    exit 0
fi

SOURCE_WORKSPACE="$(pick_alternate_workspace)"
TARGET_WORKSPACE="$ORIGINAL_WORKSPACE"
echo "[info] source workspace: $SOURCE_WORKSPACE"
echo "[info] target workspace: $TARGET_WORKSPACE"

echo "[step] switching to source workspace $SOURCE_WORKSPACE"
"$release_cli" workspace "$SOURCE_WORKSPACE"
wait_until 15 1 focused_workspace_is "$SOURCE_WORKSPACE"

echo "[step] creating the initial $target_app_name window on workspace $SOURCE_WORKSPACE via Hyprspace command"
"$release_cli" new-window-or-open "$target_cli_app"

echo "[step] verifying the initial $target_app_name window is on workspace $SOURCE_WORKSPACE"
source_workspace_windows_before=0
wait_until 30 5 terminal_windows_on_workspace_at_least "$SOURCE_WORKSPACE" 1
source_workspace_windows_before=$("$release_cli" list-windows --workspace "$SOURCE_WORKSPACE" --app-bundle-id "$target_bundle_id" --count 2>/dev/null | tr -d '[:space:]' || echo "0")
echo "[info] $target_app_name windows on workspace $SOURCE_WORKSPACE before second invocation: $source_workspace_windows_before"
if [ "$source_workspace_windows_before" -lt 1 ]; then
    echo "[fail] Expected the first Hyprspace invocation to create at least one $target_app_name window on workspace $SOURCE_WORKSPACE"
    echo "[fail] Actual: $source_workspace_windows_before"
    exit 1
fi

echo "[step] switching back to target workspace $TARGET_WORKSPACE"
"$release_cli" workspace "$TARGET_WORKSPACE"
wait_until 15 1 focused_workspace_is "$TARGET_WORKSPACE"

echo "[step] confirming no $target_app_name windows are already on workspace $TARGET_WORKSPACE"
target_workspace_windows_before=$("$release_cli" list-windows --workspace "$TARGET_WORKSPACE" --app-bundle-id "$target_bundle_id" --count 2>/dev/null | tr -d '[:space:]' || echo "0")
echo "[info] $target_app_name windows on workspace $TARGET_WORKSPACE before command: $target_workspace_windows_before"
if [ "$target_workspace_windows_before" -ne 0 ]; then
    echo "[fail] Expected zero $target_app_name windows on workspace $TARGET_WORKSPACE before the second invocation"
    echo "[fail] Actual: $target_workspace_windows_before"
    exit 1
fi

echo "[step] capturing current workspace before new-window-or-open"
current_workspace=$("$release_cli" list-workspaces --focused --format '%{workspace}' 2>/dev/null | head -1 | tr -d '[:space:]' || echo "")
echo "[info] current workspace: $current_workspace"
if [ "$current_workspace" != "$TARGET_WORKSPACE" ]; then
    echo "[fail] Expected focused workspace to be $TARGET_WORKSPACE before second invocation"
    echo "[fail] Actual focused workspace: $current_workspace"
    exit 1
fi

echo "[step] triggering new-window-or-open $target_cli_app from workspace $TARGET_WORKSPACE"
start_state_sampler "second-invocation"
"$release_cli" new-window-or-open "$target_cli_app"
if ! wait_until 8 2 terminal_windows_on_workspace_greater_than "$TARGET_WORKSPACE" "$target_workspace_windows_before"; then
    stop_state_sampler
    echo "[fail] Timed out waiting for a new $target_app_name window on workspace $TARGET_WORKSPACE"
    focused_workspace_after_timeout=$("$release_cli" list-workspaces --focused --format '%{workspace}' 2>/dev/null | head -1 | tr -d '[:space:]' || echo "")
    echo "[fail] focused workspace at timeout: $focused_workspace_after_timeout"
    target_workspace_windows_at_timeout="$(terminal_windows_on_workspace_count "$TARGET_WORKSPACE")"
    source_workspace_windows_at_timeout="$(terminal_windows_on_workspace_count "$SOURCE_WORKSPACE")"
    echo "[fail] $target_app_name windows on workspace $TARGET_WORKSPACE at timeout: $target_workspace_windows_at_timeout"
    echo "[fail] $target_app_name windows on workspace $SOURCE_WORKSPACE at timeout: $source_workspace_windows_at_timeout"
    print_workspace_topology "timeout after second invocation"
    exit 1
fi
stop_state_sampler

echo "[step] capturing focused workspace after second invocation"
focused_workspace_after=$("$release_cli" list-workspaces --focused --format '%{workspace}' 2>/dev/null | head -1 | tr -d '[:space:]' || echo "")
echo "[info] focused workspace after command: $focused_workspace_after"
WORKSPACES_AFTER_MUTATION=()
while IFS= read -r workspace || [[ -n "$workspace" ]]; do
    [[ -n "$workspace" ]] || continue
    WORKSPACES_AFTER_MUTATION+=("$workspace")
done < <(read_workspace_list)
printf '%s\n' "[info] workspaces after mutation: ${WORKSPACES_AFTER_MUTATION[*]}"
print_workspace_topology "after mutation"

echo "[step] counting $target_app_name windows after second invocation"
target_workspace_windows_after=$("$release_cli" list-windows --workspace "$TARGET_WORKSPACE" --app-bundle-id "$target_bundle_id" --count 2>/dev/null | tr -d '[:space:]' || echo "0")
echo "[info] $target_app_name windows on workspace $TARGET_WORKSPACE after command: $target_workspace_windows_after"

source_workspace_windows_after=$("$release_cli" list-windows --workspace "$SOURCE_WORKSPACE" --app-bundle-id "$target_bundle_id" --count 2>/dev/null | tr -d '[:space:]' || echo "0")
echo "[info] $target_app_name windows on workspace $SOURCE_WORKSPACE after command: $source_workspace_windows_after"

echo "[step] asserting workspace did not jump and new window opened on workspace $TARGET_WORKSPACE"
if [ "$focused_workspace_after" != "$TARGET_WORKSPACE" ]; then
    echo "[fail] Expected focused workspace to remain $TARGET_WORKSPACE after second invocation"
    echo "[fail] Actual focused workspace: $focused_workspace_after"
    exit 1
fi

if [ "$target_workspace_windows_after" -le "$target_workspace_windows_before" ]; then
    echo "[fail] Expected a new $target_app_name window to be created on workspace $TARGET_WORKSPACE"
    echo "[fail] Before: $target_workspace_windows_before"
    echo "[fail] After:  $target_workspace_windows_after"
    exit 1
fi

if [ "$source_workspace_windows_after" -ne "$source_workspace_windows_before" ]; then
    echo "[fail] Expected workspace $SOURCE_WORKSPACE to keep only the original $target_app_name window count"
    echo "[fail] Before: $source_workspace_windows_before"
    echo "[fail] After:  $source_workspace_windows_after"
    exit 1
fi

if [[ "${WORKSPACES_AFTER_MUTATION[*]}" != "${WORKSPACES_BEFORE[*]}" ]]; then
    echo "[fail] Expected workspace topology to remain unchanged during test"
    echo "[fail] Before: ${WORKSPACES_BEFORE[*]}"
    echo "[fail] After:  ${WORKSPACES_AFTER_MUTATION[*]}"
    exit 1
fi

echo "[ok] PASS: Second invocation kept focus on workspace $TARGET_WORKSPACE and created the new $target_app_name window there"
