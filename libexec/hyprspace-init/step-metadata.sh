#!/bin/bash
set -euo pipefail

OPTIONAL_STEP_KEYS=(
    "sketchybar"
    "borders"
    "macos_defaults"
    "wallpaper"
    "btop"
)

MANDATORY_STEP_KEYS=(
    "hyprspace_config"
    "hack_nerd_font"
)

step_label() {
    case "$1" in
    hyprspace_config) echo "Hyprspace config" ;;
    sketchybar) echo "Sketchybar" ;;
    borders) echo "JankyBorders" ;;
    macos_defaults) echo "macOS defaults" ;;
    wallpaper) echo "Wallpaper" ;;
    hack_nerd_font) echo "Hack Nerd Font" ;;
    btop) echo "btop" ;;
    *) return 1 ;;
    esac
}

step_key_for_label() {
    case "$1" in
    "Hyprspace config") echo "hyprspace_config" ;;
    "Sketchybar") echo "sketchybar" ;;
    "JankyBorders") echo "borders" ;;
    "macOS defaults") echo "macos_defaults" ;;
    "Wallpaper") echo "wallpaper" ;;
    "Hack Nerd Font") echo "hack_nerd_font" ;;
    "btop") echo "btop" ;;
    *) return 1 ;;
    esac
}

default_selected_keys() {
    printf '%s\n' "${OPTIONAL_STEP_KEYS[@]}"
}

mandatory_step_keys() {
    printf '%s\n' "${MANDATORY_STEP_KEYS[@]}"
}

optional_step_labels() {
    local key
    for key in "${OPTIONAL_STEP_KEYS[@]}"; do
        step_label "$key"
    done
}

default_selected_labels() {
    local key
    for key in "${OPTIONAL_STEP_KEYS[@]}"; do
        step_label "$key"
    done
}

terminal_app_choices() {
    printf '%s\n' "Ghostty" "Terminal.app"
}

default_terminal_app() {
    echo "Ghostty"
}

music_app_choices() {
    printf '%s\n' "Apple Music" "Spotify"
}

default_music_app() {
    echo "Apple Music"
}

browser_app_choices() {
    printf '%s\n' "Safari" "Helium"
}

default_browser_app() {
    echo "Safari"
}

validate_terminal_app() {
    case "$1" in
    "Ghostty" | "Terminal.app") return 0 ;;
    *) return 1 ;;
    esac
}

validate_music_app() {
    case "$1" in
    "Apple Music" | "Spotify") return 0 ;;
    *) return 1 ;;
    esac
}

validate_browser_app() {
    case "$1" in
    "Safari" | "Helium") return 0 ;;
    *) return 1 ;;
    esac
}

build_apply_flags() {
    local selected=("$@")
    local step
    local found
    local key

    for step in "${OPTIONAL_STEP_KEYS[@]}"; do
        found=0
        for key in "${selected[@]}"; do
            if [ "$key" = "$step" ]; then
                found=1
                break
            fi
        done

        if [ "$found" -ne 1 ]; then
            printf '%s\n' "--without-${step//_/-}"
        fi
    done
}

selected_step_labels() {
    local key
    for key in "$@"; do
        step_label "$key"
    done
}
