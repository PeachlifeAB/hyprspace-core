#!/bin/bash
set -euo pipefail

if [ "${HYPRSPACE_SKIP_DEPENDENCY_SETUP:-0}" = "1" ]; then
    echo "-> Skipping dependency setup (HYPRSPACE_SKIP_DEPENDENCY_SETUP=1)."
    exit 0
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "-> Homebrew is not available. Skipping opinionated dependency setup."
    exit 0
fi

enable_sketchybar="${HYPRSPACE_ENABLE_SKETCHYBAR:-1}"
enable_borders="${HYPRSPACE_ENABLE_BORDERS:-1}"
selected_terminal_app="${HYPRSPACE_SELECTED_TERMINAL_APP:-Ghostty}"
selected_music_app="${HYPRSPACE_SELECTED_MUSIC_APP:-Apple Music}"
selected_browser_app="${HYPRSPACE_SELECTED_BROWSER_APP:-Safari}"

ensure_tap() {
    local tap="$1"

    if brew tap | grep -qx "$tap"; then
        echo "-> Homebrew tap $tap already added, skipping."
    else
        echo "-> Adding Homebrew tap $tap..."
        brew tap "$tap"
    fi
}

ensure_formula() {
    local formula="$1"
    local label="$2"

    if brew list --formula "$formula" >/dev/null 2>&1; then
        echo "-> $label already installed, skipping."
    else
        echo "-> Installing $label..."
        brew install "$formula"
    fi
}

ensure_cask() {
    local cask="$1"
    local label="$2"

    if brew list --cask "$cask" >/dev/null 2>&1; then
        echo "-> $label already installed, skipping."
    else
        echo "-> Installing $label..."
        brew install --cask "$cask"
    fi
}

if [ "$enable_sketchybar" = "1" ] || [ "$enable_borders" = "1" ]; then
    ensure_tap "FelixKratz/formulae"
else
    echo "-> FelixKratz/formulae tap not needed, skipping."
fi

if [ "$enable_sketchybar" = "1" ]; then
    ensure_formula "sketchybar" "Sketchybar"
else
    echo "-> Sketchybar disabled, skipping package install."
fi

if [ "$enable_borders" = "1" ]; then
    ensure_formula "borders" "JankyBorders"
else
    echo "-> JankyBorders disabled, skipping package install."
fi

ensure_cask "font-hack-nerd-font" "Hack Nerd Font"

if [ "$selected_terminal_app" = "Ghostty" ]; then
    ensure_cask "ghostty" "Ghostty"
else
    echo "-> Terminal.app selected, skipping Ghostty install."
fi

if [ "$selected_music_app" = "Spotify" ]; then
    ensure_cask "spotify" "Spotify"
else
    echo "-> Apple Music selected, skipping Spotify install."
fi

if [ "$selected_browser_app" = "Helium" ]; then
    ensure_cask "helium-browser" "Helium"
else
    echo "-> Safari selected, skipping Helium install."
fi

if [ "${enable_btop:-1}" = "1" ]; then
    ensure_formula "btop" "btop"
else
    echo "-> btop disabled, skipping package install."
fi