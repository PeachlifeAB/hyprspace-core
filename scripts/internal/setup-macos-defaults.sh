#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
helper_path="$ROOT_DIR/libexec/hyprspace-init/hyprspace-notify-menubar"

if [ "${HYPRSPACE_SKIP_MACOS_DEFAULTS:-0}" = "1" ]; then
    echo "-> Skipping macOS defaults setup (HYPRSPACE_SKIP_MACOS_DEFAULTS=1)."
    exit 0
fi

read_default_bool() {
    local domain="$1"
    local key="$2"

    if [ "$domain" = "-g" ]; then
        defaults read -g "$key" 2>/dev/null || true
    else
        defaults read "$domain" "$key" 2>/dev/null || true
    fi
}

write_default_bool() {
    local domain="$1"
    local key="$2"
    local value="$3"

    if [ "$domain" = "-g" ]; then
        defaults write -g "$key" -bool "$value"
    else
        defaults write "$domain" "$key" -bool "$value"
    fi
}

ensure_bool_default() {
    local domain="$1"
    local key="$2"
    local expected_raw="$3"
    local write_value="$4"
    local restart_process="$5"

    local current
    current="$(read_default_bool "$domain" "$key")"

    if [ "$current" != "$expected_raw" ]; then
        echo "-> Setting $key=$write_value (was: ${current:-unset})..."
        write_default_bool "$domain" "$key" "$write_value"
        if [ -n "$restart_process" ]; then
            killall "$restart_process" 2>/dev/null || true
        fi
    else
        echo "-> $key already set, skipping."
    fi
}

ensure_bool_default "com.apple.spaces" "spans-displays" "1" "true" "SystemUIServer"
ensure_bool_default "com.apple.dock" "expose-group-apps" "1" "true" "Dock"
ensure_bool_default "-g" "NSAutomaticWindowAnimationsEnabled" "0" "false" ""

if [ "${HYPRSPACE_ENABLE_SKETCHYBAR:-0}" = "1" ]; then
    current_menubar="$(defaults read NSGlobalDomain _HIHideMenuBar 2>/dev/null || true)"
    if [ "$current_menubar" != "1" ]; then
        echo "-> Hiding menu bar (sketchybar replaces it)..."
        defaults write NSGlobalDomain _HIHideMenuBar -bool true
        if [ ! -x "$helper_path" ]; then
            echo "-> Menu bar notification helper missing at $helper_path, continuing."
        elif ! output="$($helper_path 2>&1)"; then
            echo "-> Menu bar notification helper failed, continuing without blocking init."
            printf '%s\n' "$output"
        else
            if [ -n "$output" ]; then
                printf '%s\n' "$output"
            fi
        fi
    else
        echo "-> Menu bar already hidden, skipping."
    fi
fi
