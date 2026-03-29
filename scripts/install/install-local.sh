#!/bin/bash
set -euo pipefail

# 100% safe, non-homebrew-dependent install script for Hyprspace local builds.

# Get the absolute path to the root of the repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"

if [[ "${HYPRSPACE_USE_EXISTING_RELEASE:-0}" = "1" ]]; then
    echo "======================================================"
    echo "📦 Using existing packaged release payload from AeroSpace/.release..."
    echo "======================================================"
    test -d "$ROOT_DIR/AeroSpace/.release" || {
        echo "ERROR: missing existing release payload at $ROOT_DIR/AeroSpace/.release" >&2
        exit 1
    }
else
    echo "======================================================"
    echo "🚀 Building Hyprspace from source..."
    echo "======================================================"
    cd AeroSpace

    DEV_BUILD_HASH="${HYPRSPACE_GIT_HASH:-$(git -C "$ROOT_DIR" rev-parse --short HEAD)}"
    DEV_BUILD_VERSION="$(cat "$ROOT_DIR/version.txt")-$DEV_BUILD_HASH"

    SIGN_ID="${HYPRSPACE_CODESIGN_IDENTITY:--}"
    if [[ "$SIGN_ID" != "-" ]] && ! security find-identity -v -p codesigning | grep -Fq "\"$SIGN_ID\""; then
        echo "ERROR: requested signing identity not found: $SIGN_ID" >&2
        exit 1
    fi

    # Bypass strict ruby version dependencies and missing shell-parsers using flags
    # Allow dirty tree because we are actively hacking on this fork and testing.
    ./build-release.sh \
        --build-version "$DEV_BUILD_VERSION" \
        --skip-docs \
        --skip-shell-parser \
        --codesign-identity "$SIGN_ID" \
        --allow-dirty

    cd "$ROOT_DIR"
fi

echo "======================================================"
echo "🛑 Terminating running instances of AeroSpace / Hyprspace..."
echo "======================================================"
killall AeroSpace 2>/dev/null || true
killall AeroSpaceApp 2>/dev/null || true
killall Hyprspace 2>/dev/null || true

# Wait for processes to actually die to avoid state corruption/race conditions
while pgrep -q -x AeroSpace || pgrep -q -x AeroSpaceApp || pgrep -q -x Hyprspace; do
    sleep 0.2
done

echo "======================================================"
echo "📦 Installing artifacts..."
echo "======================================================"

APP_DEST="${INSTALL_PREFIX:-/Applications}/Hyprspace.app"
BIN_DEST="${INSTALL_PREFIX:-$HOME/.local}/bin/hyprspace"

# Remove old app and copy the newly built app
echo "-> Installing $APP_DEST..."
rm -rf "$APP_DEST"
mkdir -p "$(dirname "$APP_DEST")"
cp -R "AeroSpace/.release/Hyprspace.app" "$APP_DEST"

# Install CLI tool
echo "-> Installing $BIN_DEST..."
mkdir -p "$(dirname "$BIN_DEST")"
cp "AeroSpace/.release/hyprspace" "$BIN_DEST"
chmod +x "$BIN_DEST"

# Install packaged init runtime and support assets
INSTALL_ROOT="${INSTALL_PREFIX:-$HOME/.local}"
CLI_RUNTIME_DEST="$INSTALL_ROOT/libexec/hyprspace-cli"
echo "-> Installing $CLI_RUNTIME_DEST..."
mkdir -p "$(dirname "$CLI_RUNTIME_DEST")"
cp "AeroSpace/.release/libexec/hyprspace-cli" "$CLI_RUNTIME_DEST"
chmod +x "$CLI_RUNTIME_DEST"

INIT_RUNTIME_DEST="$INSTALL_ROOT/libexec/hyprspace-init"
echo "-> Installing $INIT_RUNTIME_DEST..."
rm -rf "$INIT_RUNTIME_DEST"
mkdir -p "$(dirname "$INIT_RUNTIME_DEST")"
cp -R "AeroSpace/.release/libexec/hyprspace-init" "$INIT_RUNTIME_DEST"
chmod +x "$INIT_RUNTIME_DEST/hyprspace-init" "$INIT_RUNTIME_DEST/apply-init-selections.sh"

for support_dir in scripts artifacts AeroSpace; do
    if [ -e "$INSTALL_ROOT/$support_dir" ]; then
        rm -rf "$INSTALL_ROOT/$support_dir"
    fi
done
cp -R "AeroSpace/.release/scripts" "$INSTALL_ROOT/scripts"
cp -R "AeroSpace/.release/artifacts" "$INSTALL_ROOT/artifacts"
mkdir -p "$INSTALL_ROOT/AeroSpace/docs"
cp -R "AeroSpace/.release/AeroSpace/docs/config-examples" "$INSTALL_ROOT/AeroSpace/docs/config-examples"
chmod +x "$INSTALL_ROOT/scripts/internal/setup-dependencies.sh" "$INSTALL_ROOT/scripts/internal/setup-hyprspace-config.sh" "$INSTALL_ROOT/scripts/internal/setup-sketchybar-config.sh" "$INSTALL_ROOT/scripts/internal/setup-macos-defaults.sh" "$INSTALL_ROOT/scripts/internal/setup-wallpaper.sh"

echo "======================================================"
echo "📚 Installing opinionated companion dependencies..."
echo "======================================================"

"$ROOT_DIR/scripts/internal/setup-dependencies.sh"

echo "======================================================"
echo "⚙️  Setting up Hyprspace configuration..."
echo "======================================================"

"$ROOT_DIR/scripts/internal/setup-hyprspace-config.sh"

echo "======================================================"
echo "📊 Setting up Sketchybar integration..."
echo "======================================================"

"$ROOT_DIR/scripts/internal/setup-sketchybar-config.sh"

echo "======================================================"
echo "🖥️  Applying recommended macOS system defaults..."
echo "======================================================"

"$ROOT_DIR/scripts/internal/setup-macos-defaults.sh"

echo "======================================================"
echo "🖼️  Applying bundled wallpaper..."
echo "======================================================"

"$ROOT_DIR/scripts/internal/setup-wallpaper.sh"

echo "======================================================"
echo "✅ Installation complete!"
echo "======================================================"
echo "🚀 Starting Hyprspace..."
if [ "$APP_DEST" = "/Applications/Hyprspace.app" ]; then
    open -a Hyprspace
else
    open -a "$APP_DEST"
fi
echo "Ensure $HOME/.local/bin is in your PATH to use the 'hyprspace' CLI."
