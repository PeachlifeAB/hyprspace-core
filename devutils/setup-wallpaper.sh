#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
wallpaper_path="${HYPRSPACE_WALLPAPER_PATH:-$ROOT_DIR/gfx/wallpaper-default.jpg}"

if [ "${HYPRSPACE_SKIP_WALLPAPER_SETUP:-0}" = "1" ]; then
    echo "-> Skipping wallpaper setup (HYPRSPACE_SKIP_WALLPAPER_SETUP=1)."
    exit 0
fi

if ! command -v osascript >/dev/null 2>&1; then
    echo "-> osascript is unavailable. Skipping wallpaper setup."
    exit 0
fi

if [ ! -f "$wallpaper_path" ]; then
    echo "-> Wallpaper asset missing at $wallpaper_path. Skipping wallpaper setup."
    exit 0
fi

echo "-> Setting macOS wallpaper from $wallpaper_path..."
if ! output="$(
    WALLPAPER_PATH="$wallpaper_path" /usr/bin/swift - <<'SWIFT' 2>&1
import AppKit
import Foundation

let wallpaperPath = ProcessInfo.processInfo.environment["WALLPAPER_PATH"] ?? ""
let wallpaperURL = URL(fileURLWithPath: wallpaperPath)
let workspace = NSWorkspace.shared
let screens = NSScreen.screens

guard !screens.isEmpty else {
    fputs("No screens available for wallpaper update.\n", stderr)
    exit(1)
}

for screen in screens {
    let options = workspace.desktopImageOptions(for: screen) ?? [:]
    try workspace.setDesktopImageURL(wallpaperURL, for: screen, options: options)
}
SWIFT
)"; then
    echo "-> Wallpaper setup failed, continuing without blocking init."
    printf '%s\n' "$output"
    exit 0
fi

if [ -n "$output" ]; then
    printf '%s\n' "$output"
fi

echo "-> Wallpaper applied."
