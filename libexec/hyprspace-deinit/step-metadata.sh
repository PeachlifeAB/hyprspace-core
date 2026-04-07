#!/bin/bash
set -euo pipefail

DEINIT_STEP_KEYS=(
    "sketchybar"
    "borders"
    "hyprspace_config"
    "wallpaper"
    "macos_defaults"
    "homebrew_tap"
)

step_label() {
    case "$1" in
    sketchybar) echo "Sketchybar (uninstall + remove config)" ;;
    borders) echo "JankyBorders (uninstall)" ;;
    hyprspace_config) echo "Hyprspace config (~/.config/hyprspace)" ;;
    wallpaper) echo "Restore original wallpaper" ;;
    macos_defaults) echo "Reset macOS defaults (spaces, dock, animations)" ;;
    homebrew_tap) echo "Remove Homebrew taps" ;;
    *) return 1 ;;
    esac
}

step_key_for_label() {
    case "$1" in
    "Sketchybar (uninstall + remove config)") echo "sketchybar" ;;
    "JankyBorders (uninstall)") echo "borders" ;;
    "Hyprspace config (~/.config/hyprspace)") echo "hyprspace_config" ;;
    "Restore original wallpaper") echo "wallpaper" ;;
    "Reset macOS defaults (spaces, dock, animations)") echo "macos_defaults" ;;
    "Remove Homebrew taps") echo "homebrew_tap" ;;
    *) return 1 ;;
    esac
}

default_selected_keys() {
    printf '%s\n' "${DEINIT_STEP_KEYS[@]}"
}

deinit_step_labels() {
    local key
    for key in "${DEINIT_STEP_KEYS[@]}"; do
        step_label "$key"
    done
}

default_selected_labels() {
    local key
    for key in "${DEINIT_STEP_KEYS[@]}"; do
        step_label "$key"
    done
}

selected_step_labels() {
    local key
    for key in "$@"; do
        step_label "$key"
    done
}
