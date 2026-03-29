#!/usr/bin/env bash
set -euo pipefail

init_human_log() {
    local root_dir="$1"
    local action="$2"
    local script_name="${3:-$(basename "$0" .sh)}"

    if [[ -n "${HUMAN_FLOW_LOG_BOOTSTRAPPED:-}" ]]; then
        return 0
    fi

    mkdir -p "$root_dir/log/$action"
    HUMAN_FLOW_LOG_BOOTSTRAPPED=1
    export HUMAN_FLOW_LOG_BOOTSTRAPPED
    HUMAN_FLOW_LOG_FILE="$root_dir/log/$action/$(date -u +%Y%m%dT%H%M%SZ)-${script_name}.log"
    export HUMAN_FLOW_LOG_FILE
    exec > >(tee "$HUMAN_FLOW_LOG_FILE") 2>&1
    echo "[log] file=$HUMAN_FLOW_LOG_FILE"
}
