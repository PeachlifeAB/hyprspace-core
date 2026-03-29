#!/usr/bin/env bash
set -euo pipefail

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "[prereq] missing required command: $1"
}

hyprspace_cli_version() {
    local cli_path="$1"
    "$cli_path" --version 2>&1 | tr -d '\r'
}

hyprspace_bundle_short_version() {
    local app_path="$1"
    defaults read "$app_path/Contents/Info" CFBundleShortVersionString 2>/dev/null | tr -d '\r'
}

hyprspace_expected_display_version() {
    local short_version="$1"
    local base_version
    # shellcheck disable=SC2154
    base_version="$(tr -d '\r' <"$root_dir/aerospace_version.txt")"
    printf 'Hyprspace v%s (AeroSpace %s)\n' "$short_version" "$base_version"
}

hyprspace_assert_release_artifact_versions() {
    local release_cli="$1"
    local release_app="$2"
    local release_bundle_version
    local release_cli_version
    local expected_release_cli_version

    release_bundle_version="$(hyprspace_bundle_short_version "$release_app")"
    release_cli_version="$(hyprspace_cli_version "$release_cli")"
    expected_release_cli_version="$(hyprspace_expected_display_version "$release_bundle_version")"

    printf '%s\n' "[version] release_cli=$release_cli_version"
    printf '%s\n' "[version] release_app=$release_bundle_version"

    if [[ "$release_cli_version" != "$expected_release_cli_version" ]]; then
        printf '%s\n' "[fail] release CLI version does not match release app bundle version" >&2
        printf '%s\n' "[fail] expected release CLI: $expected_release_cli_version" >&2
        printf '%s\n' "[fail] actual release CLI:   $release_cli_version" >&2
        printf '%s\n' "[fail] release app bundle:   $release_bundle_version" >&2
        return 1
    fi
}

hyprspace_assert_live_runtime_version_alignment() {
    local release_cli="$1"
    local release_app="$2"
    local installed_cli
    local release_cli_version
    local installed_cli_version
    local release_app_version
    local installed_app_version
    local expected_release_cli_version

    installed_cli="$(command -v hyprspace || true)"
    [[ -n "$installed_cli" ]] || die "[prereq] hyprspace command not found on PATH for live runtime alignment check"
    [[ -d /Applications/Hyprspace.app ]] || die "[prereq] /Applications/Hyprspace.app not found for live runtime alignment check"

    release_cli_version="$(hyprspace_cli_version "$release_cli")"
    installed_cli_version="$(hyprspace_cli_version "$installed_cli")"
    release_app_version="$(hyprspace_bundle_short_version "$release_app")"
    installed_app_version="$(hyprspace_bundle_short_version /Applications/Hyprspace.app)"
    expected_release_cli_version="$(hyprspace_expected_display_version "$release_app_version")"

    printf '%s\n' "[version] installed_cli=$installed_cli_version"
    printf '%s\n' "[version] installed_app=$installed_app_version"

    if [[ "$release_cli_version" != "$expected_release_cli_version" ]]; then
        printf '%s\n' "[fail] freshly built release CLI version does not match expected display version" >&2
        printf '%s\n' "[fail] expected release CLI: $expected_release_cli_version" >&2
        printf '%s\n' "[fail] actual release CLI:   $release_cli_version" >&2
        return 1
    fi

    if [[ "$installed_cli_version" != "$release_cli_version" ]]; then
        printf '%s\n' "[fail] installed CLI version does not match freshly built release CLI" >&2
        printf '%s\n' "[fail] release CLI:   $release_cli_version" >&2
        printf '%s\n' "[fail] installed CLI: $installed_cli_version" >&2
        return 1
    fi

    if [[ "$installed_app_version" != "$release_app_version" ]]; then
        printf '%s\n' "[fail] installed app version does not match freshly built release app" >&2
        printf '%s\n' "[fail] release app:   $release_app_version" >&2
        printf '%s\n' "[fail] installed app: $installed_app_version" >&2
        return 1
    fi
}

make_temp_dir() {
    local base="${TMPDIR:-/tmp}"
    mktemp -d "${base%/}/hyprspace-test.XXXXXXXX"
}

register_cleanup_path() {
    declare -p HYPRSPACE_TEST_CLEANUP_PATHS >/dev/null 2>&1 || die "[error] HYPRSPACE_TEST_CLEANUP_PATHS must be declared as an array"
    local path
    for path in "$@"; do
        HYPRSPACE_TEST_CLEANUP_PATHS+=("$path")
    done
}

cleanup_paths_on_exit() {
    local path
    for path in "${HYPRSPACE_TEST_CLEANUP_PATHS[@]:-}"; do
        [[ -n "${path:-}" ]] || continue
        rm -rf "$path" 2>/dev/null || true
    done
}

require_opt_in() {
    local var_name="$1"
    local message="$2"
    local enabled="${!var_name:-0}"

    if [[ "$enabled" != "1" ]]; then
        printf '%s\n' "[skip] ${message}" >&2
        printf '%s\n' "[skip] Re-run with ${var_name}=1." >&2
        exit 0
    fi
}

wait_until() {
    local timeout_s="$1"
    local interval_s="$2"
    local started_at current_at per_try_timeout attempt_pid attempt_started attempt_status remaining_s
    shift 2

    started_at="$(date +%s)"
    while true; do
        current_at="$(date +%s)"
        if ((current_at - started_at >= timeout_s)); then
            return 1
        fi

        remaining_s=$((timeout_s - (current_at - started_at)))
        per_try_timeout="$interval_s"
        if ((per_try_timeout < 1)); then
            per_try_timeout=1
        fi
        if ((per_try_timeout > remaining_s)); then
            per_try_timeout=$remaining_s
        fi

        attempt_status=''
        ("$@") &
        attempt_pid=$!
        attempt_started="$(date +%s)"

        while kill -0 "$attempt_pid" 2>/dev/null; do
            current_at="$(date +%s)"
            if ((current_at - started_at >= timeout_s)); then
                kill "$attempt_pid" 2>/dev/null || true
                wait "$attempt_pid" 2>/dev/null || true
                return 1
            fi

            if ((current_at - attempt_started >= per_try_timeout)); then
                printf '%s\n' "[wait_until] timed out after ${per_try_timeout}s: $*" >&2
                kill "$attempt_pid" 2>/dev/null || true
                wait "$attempt_pid" 2>/dev/null || true
                attempt_status=124
                break
            fi

            sleep 1
        done

        if [[ -z "$attempt_status" ]]; then
            if wait "$attempt_pid"; then
                attempt_status=0
            else
                attempt_status=$?
            fi
        fi
        if [[ "$attempt_status" -eq 0 ]]; then
            return 0
        fi

        current_at="$(date +%s)"
        if ((current_at - started_at >= timeout_s)); then
            return 1
        fi

        sleep "$interval_s"
    done
}

resolve_path() {
    require_cmd python3
    P="$1" python3 -c 'import os, pathlib; print(pathlib.Path(os.environ["P"]).resolve())'
}

hyprspace_process_count() {
    local app_name="$1"
    pgrep -x "$app_name" >/dev/null 2>&1 || {
        printf '0\n'
        return 0
    }
    pgrep -x "$app_name" | wc -l | tr -d '[:space:]'
}

hyprspace_snapshot_tracked_apps() {
    local output_path="$1"
    declare -p HYPRSPACE_TEST_TRACKED_APPS >/dev/null 2>&1 || die "[error] HYPRSPACE_TEST_TRACKED_APPS must be declared as an array"

    : >"$output_path"
    local app_name
    for app_name in "${HYPRSPACE_TEST_TRACKED_APPS[@]:-}"; do
        [[ -n "${app_name:-}" ]] || continue
        printf '%s\t%s\n' "$app_name" "$(hyprspace_process_count "$app_name")" >>"$output_path"
    done
}

hyprspace_window_snapshot_cli() {
    if [[ -n "${HYPRSPACE_TEST_WINDOW_CLI:-}" ]]; then
        printf '%s\n' "$HYPRSPACE_TEST_WINDOW_CLI"
        return 0
    fi

    if command -v hyprspace >/dev/null 2>&1; then
        command -v hyprspace
        return 0
    fi

    return 1
}

hyprspace_snapshot_window_state() {
    local output_path="$1"
    local cli

    if ! cli="$(hyprspace_window_snapshot_cli)"; then
        printf 'WINDOW_STATE_UNAVAILABLE\tmissing-cli\n' >"$output_path"
        return 0
    fi

    if ! [[ -x "$cli" ]] && ! command -v "$cli" >/dev/null 2>&1; then
        printf 'WINDOW_STATE_UNAVAILABLE\tmissing-cli\t%s\n' "$cli" >"$output_path"
        return 0
    fi

    if "$cli" list-windows --all >/dev/null 2>&1; then
        "$cli" list-windows --all | LC_ALL=C sort >"$output_path"
        return 0
    fi

    printf 'WINDOW_STATE_UNAVAILABLE\tcli-not-ready\t%s\n' "$cli" >"$output_path"
}

hyprspace_print_snapshot() {
    local label="$1"
    local file_path="$2"

    printf '%s\n' "[snapshot] $label"
    while IFS= read -r line || [[ -n "$line" ]]; do
        printf '%s\n' "[snapshot]   $line"
    done <"$file_path"
}

hyprspace_server_pid_running() {
    [[ -n "${HYPRSPACE_PID:-}" ]] && kill -0 "$HYPRSPACE_PID" 2>/dev/null
}

hyprspace_assert_server_running() {
    local label="$1"

    if hyprspace_server_pid_running; then
        printf '%s\n' "[info] hyprspace_server_alive[$label]=pid=$HYPRSPACE_PID"
        return 0
    fi

    printf '%s\n' "[fail] hyprspace_server_missing[$label]=pid=${HYPRSPACE_PID:-unset}" >&2
    pgrep -fl "Hyprspace|AeroSpace" || true
    return 1
}

hyprspace_capture_clean_slate_baseline() {
    declare -p HYPRSPACE_TEST_TRACKED_APPS >/dev/null 2>&1 || die "[error] HYPRSPACE_TEST_TRACKED_APPS must be declared as an array"

    HYPRSPACE_TEST_STATE_DIR="$(make_temp_dir)"
    register_cleanup_path "$HYPRSPACE_TEST_STATE_DIR"

    HYPRSPACE_TEST_APPS_BEFORE="$HYPRSPACE_TEST_STATE_DIR/apps.before"
    HYPRSPACE_TEST_APPS_AFTER="$HYPRSPACE_TEST_STATE_DIR/apps.after"
    HYPRSPACE_TEST_WINDOWS_BEFORE="$HYPRSPACE_TEST_STATE_DIR/windows.before"
    HYPRSPACE_TEST_WINDOWS_AFTER="$HYPRSPACE_TEST_STATE_DIR/windows.after"

    hyprspace_snapshot_tracked_apps "$HYPRSPACE_TEST_APPS_BEFORE"
    hyprspace_snapshot_window_state "$HYPRSPACE_TEST_WINDOWS_BEFORE"
    HYPRSPACE_TEST_WINDOWS_BASELINE_AVAILABLE=0
    if ! grep -q '^WINDOW_STATE_UNAVAILABLE' "$HYPRSPACE_TEST_WINDOWS_BEFORE"; then
        HYPRSPACE_TEST_WINDOWS_BASELINE_AVAILABLE=1
    fi
    hyprspace_print_snapshot "tracked-apps before" "$HYPRSPACE_TEST_APPS_BEFORE"
    hyprspace_print_snapshot "windows before" "$HYPRSPACE_TEST_WINDOWS_BEFORE"
    HYPRSPACE_TEST_CLEAN_SLATE_ACTIVE=1
}

hyprspace_assert_clean_slate() {
    if [[ "${HYPRSPACE_TEST_CLEAN_SLATE_ACTIVE:-0}" != "1" ]]; then
        return 0
    fi

    hyprspace_snapshot_tracked_apps "$HYPRSPACE_TEST_APPS_AFTER"
    hyprspace_snapshot_window_state "$HYPRSPACE_TEST_WINDOWS_AFTER"
    hyprspace_print_snapshot "tracked-apps after" "$HYPRSPACE_TEST_APPS_AFTER"
    hyprspace_print_snapshot "windows after" "$HYPRSPACE_TEST_WINDOWS_AFTER"

    local failed=0
    if ! diff -u "$HYPRSPACE_TEST_APPS_BEFORE" "$HYPRSPACE_TEST_APPS_AFTER"; then
        printf '%s\n' "[fail] tracked app state changed during test" >&2
        failed=1
    fi

    if [[ "${HYPRSPACE_TEST_WINDOWS_BASELINE_AVAILABLE:-0}" = "1" ]]; then
        if ! diff -u "$HYPRSPACE_TEST_WINDOWS_BEFORE" "$HYPRSPACE_TEST_WINDOWS_AFTER"; then
            printf '%s\n' "[fail] window state changed during test" >&2
            failed=1
        fi
    else
        printf '%s\n' "[info] window-state equality skipped because baseline snapshot was unavailable"
    fi

    return "$failed"
}

hyprspace_finish_test() {
    local status="$1"
    local cleanup_fn="${2:-}"
    local guard_status=0
    local server_cleanup_status=0

    trap - EXIT INT TERM

    if [[ -n "$cleanup_fn" ]] && declare -F "$cleanup_fn" >/dev/null 2>&1; then
        "$cleanup_fn"
    fi

    if hyprspace_server_pid_running; then
        kill "$HYPRSPACE_PID" 2>/dev/null || true
        server_cleanup_status=$?
    fi

    if ! hyprspace_assert_clean_slate; then
        guard_status=$?
    fi

    cleanup_paths_on_exit

    if [[ "$status" -ne 0 ]]; then
        exit "$status"
    fi

    if [[ "$guard_status" -ne 0 ]]; then
        exit "$guard_status"
    fi

    exit "$server_cleanup_status"
}

require_no_preexisting_window_manager() {
    local running=()

    if pgrep -x AeroSpace >/dev/null 2>&1; then
        running+=("AeroSpace")
    fi
    if pgrep -x Hyprspace >/dev/null 2>&1; then
        running+=("Hyprspace")
    fi

    if [[ "${#running[@]}" -gt 0 ]]; then
        printf '%s\n' "[skip] pre-existing window manager process detected (${running[*]}). Refusing to disturb user state." >&2
        exit 0
    fi
}

require_tracked_apps_not_running() {
    declare -p HYPRSPACE_TEST_TRACKED_APPS >/dev/null 2>&1 || die "[error] HYPRSPACE_TEST_TRACKED_APPS must be declared as an array"

    local running=()
    local app_name
    for app_name in "${HYPRSPACE_TEST_TRACKED_APPS[@]:-}"; do
        [[ -n "${app_name:-}" ]] || continue
        if pgrep -x "$app_name" >/dev/null 2>&1; then
            running+=("$app_name")
        fi
    done

    if [[ "${#running[@]}" -gt 0 ]]; then
        printf '%s\n' "[skip] tracked app already running (${running[*]}). Refusing to disturb user state." >&2
        exit 0
    fi
}
