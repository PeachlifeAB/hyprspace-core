#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

FAST_TESTS=(
    tests/test-hyprspace-config-bootstrap.sh
    tests/test-hyprspace-init-apply.sh
    tests/test-hyprspace-init-defaults.sh
    tests/test-hyprspace-init-selection-preview.sh
    tests/test-hyprspace-init-ruby-runtime.sh
    tests/test-hyprspace-init-interactive-smoke.sh
    tests/test-hyprspace-cli-identity.sh
    tests/test-hyprspace-install-surface.sh
    tests/test-hyprspace-runtime-identity.sh
    tests/test-hyprspace-init-help.sh
    tests/test-hyprspace-init-notty.sh
    tests/test-hyprspace-init-tty-runtime.sh
    tests/test-hyprspace-init-required.sh
    tests/test-hyprspace-update-surface.sh
    tests/test-hyprspace-deinit-surface.sh
)

INTEGRATION_TESTS=(
    tests/test-hyprspace-release-build.sh
    tests/test-hyprspace-local-install.sh
    tests/test-hyprspace-brew-cask.sh
    tests/test-hyprspace-new-window-or-open.sh
    tests/test-hyprspace-new-window-window-count.sh
    tests/test-hyprspace-new-window-workspace-regression.sh
    tests/test-hyprspace-app-menu.sh
)

DESTRUCTIVE_TESTS=(
    tests/test-hyprspace-real-install.sh
)

RUNTIME_SENSITIVE_TESTS=(
    tests/test-hyprspace-new-window-or-open.sh
    tests/test-hyprspace-new-window-window-count.sh
    tests/test-hyprspace-new-window-workspace-regression.sh
    tests/test-hyprspace-app-menu.sh
    tests/test-hyprspace-real-install.sh
)

is_runtime_sensitive_test() {
    local candidate="$1"
    local test_script

    for test_script in "${RUNTIME_SENSITIVE_TESTS[@]}"; do
        if [[ "$test_script" == "$candidate" ]]; then
            return 0
        fi
    done

    return 1
}

require_no_duplicate_window_managers() {
    local test_script="$1"
    local running=()
    local running_count

    if pgrep -x AeroSpace >/dev/null 2>&1; then
        running+=("AeroSpace")
    fi
    if pgrep -x Hyprspace >/dev/null 2>&1; then
        running+=("Hyprspace")
    fi

    running_count="${#running[@]}"
    if [[ "$running_count" -gt 1 ]]; then
        echo "[prereq] duplicate window manager processes detected (${running[*]}). Refusing to run runtime-sensitive test: $test_script" >&2
        pgrep -fl "Hyprspace|AeroSpace" || true
        exit 1
    fi
}

run_test() {
    local test_script="$1"

    echo "▶️  Running $test_script"
    if is_runtime_sensitive_test "$test_script"; then
        require_no_duplicate_window_managers "$test_script"
    fi
    if bash "$test_script"; then
        echo "✅ $test_script passed"
    else
        echo "❌ $test_script failed"
        exit 1
    fi
    echo ""
}

run_group() {
    local label="$1"
    shift
    local test_script

    echo "========================================="
    echo "$label"
    echo "========================================="
    for test_script in "$@"; do
        run_test "$test_script"
    done
}

echo "========================================="
echo "Running all tests..."
echo "========================================="

cd "$ROOT_DIR"

if [[ "${SKIP_PREFLIGHT:-0}" != "1" ]]; then
    bash scripts/verify/patch-stack-preflight.sh
    bash scripts/patch/verify-generated-patches.sh
fi

if [[ "${RUN_ALL_TESTS:-0}" == "1" ]]; then
    RUN_INTEGRATION_TESTS=1
    RUN_DESTRUCTIVE_TESTS=1
fi

run_group "Running default fast test tier" "${FAST_TESTS[@]}"

if [[ "${RUN_INTEGRATION_TESTS:-0}" == "1" ]]; then
    run_group "Running opt-in integration tier" "${INTEGRATION_TESTS[@]}"
else
    echo "[info] Skipping integration tier. Re-run with RUN_INTEGRATION_TESTS=1."
fi

if [[ "${RUN_DESTRUCTIVE_TESTS:-0}" == "1" ]]; then
    run_group "Running opt-in destructive tier" "${DESTRUCTIVE_TESTS[@]}"
else
    echo "[info] Skipping destructive tier. Re-run with RUN_DESTRUCTIVE_TESTS=1."
fi

echo "🎉 All tests passed!"
