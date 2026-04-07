#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_DIR="$ROOT_DIR/libexec/hyprspace-init"
MACOS_TARGET="15.0"

if [ "$#" -eq 0 ]; then
    echo "usage: $0 <runtime-dir> [<runtime-dir> ...]" >&2
    exit 2
fi

for tool in xcrun; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: required tool '$tool' is unavailable" >&2
        exit 1
    fi
done

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"

build_dir="$(mktemp -d)"
cleanup() {
    rm -rf "$build_dir"
}
trap cleanup EXIT

build_helper() {
    local name="$1"
    local source_file="$SOURCE_DIR/$name.swift"
    local arm64_binary="$build_dir/$name.arm64"
    local x86_64_binary="$build_dir/$name.x86_64"
    local universal_binary="$build_dir/$name"

    if [ ! -f "$source_file" ]; then
        echo "ERROR: missing helper source at $source_file" >&2
        exit 1
    fi

    xcrun swiftc -O -sdk "$SDK_PATH" -target "arm64-apple-macos${MACOS_TARGET}" -o "$arm64_binary" "$source_file"
    xcrun swiftc -O -sdk "$SDK_PATH" -target "x86_64-apple-macos${MACOS_TARGET}" -o "$x86_64_binary" "$source_file"
    xcrun lipo -create -output "$universal_binary" "$arm64_binary" "$x86_64_binary"
    chmod +x "$universal_binary"
}

install_helper() {
    local name="$1"
    shift
    local destination_dir

    for destination_dir in "$@"; do
        mkdir -p "$destination_dir"
        cp "$build_dir/$name" "$destination_dir/$name"
        chmod +x "$destination_dir/$name"
    done
}

helpers=(
    hyprspace-notify-menubar
    hyprspace-set-wallpaper
    hyprspace-get-wallpaper
)

for helper in "${helpers[@]}"; do
    build_helper "$helper"
    install_helper "$helper" "$@"
done
