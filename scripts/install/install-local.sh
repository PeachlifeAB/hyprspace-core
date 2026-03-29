#!/bin/bash
set -euo pipefail

# 100% safe, non-homebrew-dependent install script for Hyprspace local builds.

# Get the absolute path to the root of the repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/scripts/internal/init-human-log.sh"
init_human_log "$ROOT_DIR" install install-local
cd "$ROOT_DIR"
source "$ROOT_DIR/product.conf"

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

    SIGN_ID="$HYPRSPACE_CODESIGN_IDENTITY"
    if [[ "$SIGN_ID" != "-" ]] && ! security find-identity -v -p codesigning | grep -Fq "\"$SIGN_ID\""; then
        echo "WARNING: signing identity not found: $SIGN_ID — falling back to adhoc signing (-)" >&2
        SIGN_ID="-"
    fi

    # Bypass strict ruby version dependencies and missing shell-parsers using flags
    # Allow dirty tree because we are actively hacking on this fork and testing.
    ./script/internal/build-release.sh \
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

release_root="$ROOT_DIR/AeroSpace/.release"
install_prefix="${INSTALL_PREFIX:-}"
legacy_root="$HOME/.local"

default_homebrew_prefix() {
    if command -v brew >/dev/null 2>&1; then
        brew --prefix
    elif [ "$(uname -m)" = "arm64" ]; then
        printf '%s\n' "/opt/homebrew"
    else
        printf '%s\n' "/usr/local"
    fi
}

if [ -n "$install_prefix" ]; then
    APP_DEST="$install_prefix/Hyprspace.app"
    BIN_DEST="$install_prefix/bin/hyprspace"
    LIBEXEC_DEST="$install_prefix/libexec"
    SCRIPTS_DEST="$install_prefix/scripts"
    ARTIFACTS_DEST="$install_prefix/artifacts"
    live_install=0
else
    APP_DEST="/Applications/Hyprspace.app"
    BREW_PREFIX="$(default_homebrew_prefix)"
    BIN_DEST="$BREW_PREFIX/bin/hyprspace"
    live_install=1
fi

# Remove old app and copy the newly built app
echo "-> Installing $APP_DEST..."
rm -rf "$APP_DEST"
mkdir -p "$(dirname "$APP_DEST")"
cp -R "$release_root/Hyprspace.app" "$APP_DEST"

# Install CLI tool as a symlink to the app bundle
echo "-> Creating symlink at $BIN_DEST..."
mkdir -p "$(dirname "$BIN_DEST")"
ln -sf "$APP_DEST/Contents/Resources/bin/hyprspace" "$BIN_DEST"

if [ "$live_install" -eq 0 ]; then
    echo "-> Mirroring packaged support files into $install_prefix..."
    rm -rf "$LIBEXEC_DEST" "$SCRIPTS_DEST" "$ARTIFACTS_DEST"
    mkdir -p "$LIBEXEC_DEST"
    cp -R "$APP_DEST/Contents/Resources/libexec"/. "$LIBEXEC_DEST/"
    cp -R "$release_root/scripts" "$SCRIPTS_DEST"
    cp -R "$release_root/artifacts" "$ARTIFACTS_DEST"
else
    echo "-> Purging legacy installs from $legacy_root..."
    rm -f "$legacy_root/bin/hyprspace"
    rm -rf "$legacy_root/libexec/hyprspace-cli"
    rm -rf "$legacy_root/libexec/hyprspace-init"
    rm -rf "$legacy_root/libexec/hyprspace-update"
    rm -rf "$legacy_root/scripts/internal/setup-dependencies.sh" 2>/dev/null || true
    rm -rf "$legacy_root/artifacts/hyprspace" 2>/dev/null || true
fi

echo "======================================================"
echo "📚 Installing opinionated companion dependencies..."
echo "======================================================"

"$ROOT_DIR/scripts/internal/build-init-helpers.sh" "$ROOT_DIR/libexec/hyprspace-init"

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
echo "Ensure $(dirname "$BIN_DEST") is in your PATH to use the 'hyprspace' CLI."
