#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Resolve the cleanup script. Inside an app bundle the layout is:
#   Contents/Resources/libexec/hyprspace-deinit/apply-deinit-selections.sh
#   Contents/Resources/scripts/install/cleanup-hyprspace.sh
# From a repo / standalone layout:
#   libexec/hyprspace-deinit/apply-deinit-selections.sh
#   scripts/install/cleanup-hyprspace.sh

resolve_cleanup_script() {
    local candidate

    # App bundle layout: ../../scripts/install/cleanup-hyprspace.sh
    candidate="$SCRIPT_DIR/../../scripts/install/cleanup-hyprspace.sh"
    if [ -f "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    echo "ERROR: cannot locate cleanup-hyprspace.sh from $SCRIPT_DIR" >&2
    return 1
}

enable_sketchybar=1
enable_borders=1
enable_hyprspace_config=1
enable_wallpaper=1
enable_macos_defaults=1
enable_homebrew_tap=1

while [ $# -gt 0 ]; do
    case "$1" in
    --with-sketchybar) enable_sketchybar=1 ;;
    --without-sketchybar) enable_sketchybar=0 ;;
    --with-borders) enable_borders=1 ;;
    --without-borders) enable_borders=0 ;;
    --with-hyprspace-config) enable_hyprspace_config=1 ;;
    --without-hyprspace-config) enable_hyprspace_config=0 ;;
    --with-wallpaper) enable_wallpaper=1 ;;
    --without-wallpaper) enable_wallpaper=0 ;;
    --with-macos-defaults) enable_macos_defaults=1 ;;
    --without-macos-defaults) enable_macos_defaults=0 ;;
    --with-homebrew-tap) enable_homebrew_tap=1 ;;
    --without-homebrew-tap) enable_homebrew_tap=0 ;;
    *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
    esac
    shift
done

cleanup_script="$(resolve_cleanup_script)"

cleanup_args=(--apply)

if [ "$enable_macos_defaults" = "1" ]; then
    cleanup_args+=(--reset-macos-defaults)
fi

if [ "$enable_homebrew_tap" = "1" ]; then
    cleanup_args+=(--remove-tap)
fi

# Resolve the real user's home directory — works whether or not sudo is in play.
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(dscl . -read "/Users/$TARGET_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
if [ -z "$TARGET_HOME" ] || [ ! -d "$TARGET_HOME" ]; then
    TARGET_HOME="$HOME"
fi

BACKUP_ZIP="$TARGET_HOME/hyprspace-backup.zip"

echo "======================================================"
echo "Applying selected Hyprspace deinit steps..."
echo "======================================================"

# ---------------------------------------------------------------------------
# Phase 1: Capture volatile state and create backup zip BEFORE anything
#           destructive happens. The cleanup script deletes config dirs,
#           so we must snapshot them now.
# ---------------------------------------------------------------------------

saved_wallpaper=""
if [ "$enable_wallpaper" = "1" ]; then
    wallpaper_file="$TARGET_HOME/.config/hyprspace/.wallpaper-backup"
    if [ -f "$wallpaper_file" ]; then
        saved_wallpaper="$(head -1 "$wallpaper_file")"
    fi
fi

# Build the backup zip from config dirs that still exist right now.
backup_staging="$(mktemp -d)"
has_backup_content=0

hyprspace_config="$TARGET_HOME/.config/hyprspace"
if [ -d "$hyprspace_config" ]; then
    mkdir -p "$backup_staging/hyprspace"
    cp -R "$hyprspace_config/." "$backup_staging/hyprspace/"
    has_backup_content=1
fi

sketchybar_config="$TARGET_HOME/.config/sketchybar"
if [ -d "$sketchybar_config" ]; then
    mkdir -p "$backup_staging/sketchybar"
    cp -R "$sketchybar_config/." "$backup_staging/sketchybar/"
    has_backup_content=1
fi

if [ "$has_backup_content" = "1" ]; then
    rm -f "$BACKUP_ZIP"
    (cd "$backup_staging" && /usr/bin/zip -rq "$BACKUP_ZIP" .)
    if [ ! -s "$BACKUP_ZIP" ]; then
        echo "ERROR: backup zip was not created at $BACKUP_ZIP, aborting." >&2
        rm -rf "$backup_staging"
        exit 1
    fi
    ls -lh "$BACKUP_ZIP"
    echo "-> Config backup saved to $BACKUP_ZIP"
else
    echo "-> No configs to back up."
fi
rm -rf "$backup_staging"

# ---------------------------------------------------------------------------
# Phase 2: Stop + uninstall optional Homebrew components
# ---------------------------------------------------------------------------

if command -v brew >/dev/null 2>&1; then
    if [ "$enable_sketchybar" = "1" ]; then
        echo "-> Stopping Sketchybar..."
        brew services stop sketchybar >/dev/null 2>&1 || true
        killall sketchybar >/dev/null 2>&1 || true
        if brew list --formula --versions sketchybar >/dev/null 2>&1; then
            echo "-> Uninstalling Sketchybar..."
            brew uninstall sketchybar || true
        else
            echo "-> Sketchybar not installed, skipping."
        fi
    else
        echo "-> Keeping Sketchybar (not selected for removal)."
    fi

    if [ "$enable_borders" = "1" ]; then
        echo "-> Stopping JankyBorders..."
        brew services stop borders >/dev/null 2>&1 || true
        killall borders >/dev/null 2>&1 || true
        if brew list --formula --versions borders >/dev/null 2>&1; then
            echo "-> Uninstalling JankyBorders..."
            brew uninstall borders || true
        else
            echo "-> JankyBorders not installed, skipping."
        fi
    else
        echo "-> Keeping JankyBorders (not selected for removal)."
    fi
fi

# ---------------------------------------------------------------------------
# Phase 3: Run the core cleanup script
# ---------------------------------------------------------------------------
# Tell the cleanup script to skip its own backup -- we already did it above.
# This avoids any risk of the cleanup script's destructive operations
# interfering with the backup zip.

echo "-> Running core Hyprspace cleanup..."
HYPRSPACE_DEINIT_SKIP_BACKUP=1 "$cleanup_script" "${cleanup_args[@]}"

# ---------------------------------------------------------------------------
# Phase 4: Verify backup zip survived the cleanup
# ---------------------------------------------------------------------------
if [ "$has_backup_content" = "1" ]; then
    if [ -f "$BACKUP_ZIP" ]; then
        echo "-> Backup verified: $BACKUP_ZIP"
    else
        echo "WARNING: backup zip at $BACKUP_ZIP was deleted during cleanup!" >&2
    fi
fi

# ---------------------------------------------------------------------------
# Phase 5: Restore wallpaper (uses value captured in Phase 1)
# ---------------------------------------------------------------------------
if [ "$enable_wallpaper" = "1" ]; then
    if [ -n "$saved_wallpaper" ] && [ -f "$saved_wallpaper" ]; then
        set_helper="$SCRIPT_DIR/../hyprspace-init/hyprspace-set-wallpaper"
        if [ -x "$set_helper" ]; then
            echo "-> Restoring wallpaper to $saved_wallpaper..."
            if "$set_helper" "$saved_wallpaper" >/dev/null 2>&1; then
                echo "-> Wallpaper restored."
            else
                echo "-> Wallpaper restore failed (helper returned error), skipping."
            fi
        else
            echo "-> Wallpaper setter not found at $set_helper, skipping restore."
        fi
    elif [ -n "$saved_wallpaper" ]; then
        echo "-> Saved wallpaper file no longer exists ($saved_wallpaper), skipping restore."
    else
        echo "-> No wallpaper backup found, skipping restore."
    fi
else
    echo "-> Keeping current wallpaper (not selected for restore)."
fi

# ---------------------------------------------------------------------------
# Phase 6: If user chose NOT to remove config, restore from backup
# ---------------------------------------------------------------------------
if [ "$enable_hyprspace_config" = "0" ]; then
    config_dir="$TARGET_HOME/.config/hyprspace"
    if [ -f "$BACKUP_ZIP" ]; then
        if unzip -l "$BACKUP_ZIP" 'hyprspace/*' >/dev/null 2>&1; then
            echo "-> Restoring Hyprspace config from backup..."
            restore_tmp="$(mktemp -d)"
            unzip -qo "$BACKUP_ZIP" 'hyprspace/*' -d "$restore_tmp"
            mkdir -p "$config_dir"
            cp -R "$restore_tmp/hyprspace/." "$config_dir/"
            rm -rf "$restore_tmp"
            echo "-> Config restored to $config_dir"
        else
            echo "-> Backup zip exists but contains no hyprspace config, skipping restore."
        fi
    else
        echo "-> No backup zip found at $BACKUP_ZIP, cannot restore config."
    fi
fi

# ---------------------------------------------------------------------------
# Post-cleanup: copy dotfile backup to a visible path for discoverability
# ---------------------------------------------------------------------------
if [ "$has_backup_content" = "1" ] && [ -f "$BACKUP_ZIP" ]; then
    VISIBLE_BACKUP_ZIP="$TARGET_HOME/hyprspace-backup.zip"
    cp -f "$BACKUP_ZIP" "$VISIBLE_BACKUP_ZIP"
    echo "-> Backup copy saved to $VISIBLE_BACKUP_ZIP"
fi

echo "======================================================"
echo "Hyprspace deinit complete."
echo "======================================================"
