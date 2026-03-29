#!/usr/bin/env bash
set -euo pipefail

if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "error: bash 4+ required (macOS ships bash 3; install via 'brew install bash')" >&2
    exit 1
fi

APPLY=0
AGGRESSIVE=1
REMOVE_TAP=0
RESET_MACOS_DEFAULTS=0

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
source "$root_dir/script/repo-state-table.sh"

SNAPSHOT_ROOT="$root_dir/../snapshots/Hyprspace/local-configs"
HYPRSPACE_CONFIG_DIR="$HOME/.config/hyprspace"
HYPRSPACE_CONFIG_BACKUP_DIR="$SNAPSHOT_ROOT/hyprspace-$(date -u +%Y%m%dT%H%M%SZ)"
SKETCHYBAR_CONFIG_DIR="$HOME/.config/sketchybar"
SKETCHYBAR_CONFIG_BACKUP_DIR="$SNAPSHOT_ROOT/sketchybar-$(date -u +%Y%m%dT%H%M%SZ)"

MANAGED_PROCESSES=(Hyprspace AeroSpace sketchybar borders)

declare -A SEEN_DELETE_PATHS=()

usage() {
    cat <<'EOF'
Usage: devutils/cleanup-hyprspace.sh [--apply] [--remove-tap] [--reset-macos-defaults]

Dry-run by default. Shows the Hyprspace traces that would be removed.
Normal cleanup removes all proven Hyprspace traces.
On --apply, the script backs up `~/.config/hyprspace` before deleting it.

Options:
  --apply       Actually remove discovered traces
  --remove-tap  Also untap the legacy Homebrew tap reference
  --reset-macos-defaults  Best-effort reset of macOS defaults changed by Hyprspace setup
  -h, --help    Show this help
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
    --apply) APPLY=1 ;;
    --remove-tap) REMOVE_TAP=1 ;;
    --reset-macos-defaults) RESET_MACOS_DEFAULTS=1 ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
    shift
done

run() {
    if [ "$APPLY" -eq 1 ]; then
        "$@"
    else
        printf '[dry-run] '
        printf '%q ' "$@"
        printf '\n'
    fi
}

note() {
    printf '%s\n' "$1"
}

error() {
    printf '%s\n' "$1" >&2
}

print_cleanup_state() {
    local label="$1"
    note "== State snapshot: $label =="
    print_default_repo_state_table "$label"
    print_current_system_artifact_state "$label"
}

backup_hyprspace_config() {
    if [ ! -d "$HYPRSPACE_CONFIG_DIR" ]; then
        note "[info] config backup: $HYPRSPACE_CONFIG_DIR is absent"
        return
    fi

    note "[info] config backup source: $HYPRSPACE_CONFIG_DIR"
    note "[info] config backup destination: $HYPRSPACE_CONFIG_BACKUP_DIR"
    if [ "$APPLY" -eq 1 ]; then
        mkdir -p "$HYPRSPACE_CONFIG_BACKUP_DIR"
        cp -R "$HYPRSPACE_CONFIG_DIR/." "$HYPRSPACE_CONFIG_BACKUP_DIR/"
    else
        note "[dry-run] would back up $HYPRSPACE_CONFIG_DIR to $HYPRSPACE_CONFIG_BACKUP_DIR"
    fi
}

backup_sketchybar_surface() {
    if [ ! -d "$SKETCHYBAR_CONFIG_DIR" ]; then
        note "[info] sketchybar backup: $SKETCHYBAR_CONFIG_DIR is absent"
        return
    fi

    note "[info] sketchybar backup source: $SKETCHYBAR_CONFIG_DIR"
    note "[info] sketchybar backup destination: $SKETCHYBAR_CONFIG_BACKUP_DIR"
    if [ "$APPLY" -eq 1 ]; then
        mkdir -p "$SKETCHYBAR_CONFIG_BACKUP_DIR"
        cp -R "$SKETCHYBAR_CONFIG_DIR/." "$SKETCHYBAR_CONFIG_BACKUP_DIR/"
    else
        note "[dry-run] would back up $SKETCHYBAR_CONFIG_DIR to $SKETCHYBAR_CONFIG_BACKUP_DIR"
    fi
}

delete_path() {
    local target="$1"
    if [ -e "$target" ] || [ -L "$target" ]; then
        if [ -n "${SEEN_DELETE_PATHS[$target]:-}" ]; then
            return
        fi
        SEEN_DELETE_PATHS[$target]=1
        run rm -rf "$target"
    fi
}

delete_glob() {
    local pattern="$1"
    local matches=()
    local match
    shopt -s nullglob globstar
    mapfile -t matches < <(compgen -G "$pattern" || true)
    shopt -u nullglob globstar
    for match in "${matches[@]}"; do
        delete_path "$match"
    done
}

delete_path_if_marked() {
    local target="$1"
    shift

    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
        return
    fi

    local marker
    for marker in "$@"; do
        if [ ! -e "$marker" ] && [ ! -L "$marker" ]; then
            return
        fi
    done

    delete_path "$target"
}

delete_empty_dir() {
    local target="$1"
    if [ ! -d "$target" ]; then
        return
    fi
    if [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
        return
    fi
    if [ "$APPLY" -eq 1 ]; then
        rmdir "$target"
    else
        note "[dry-run] rmdir $target"
    fi
}

cleanup_file_lines() {
    local file="$1"
    shift
    if [ ! -f "$file" ]; then
        return
    fi
    if [ "$APPLY" -eq 0 ]; then
        note "[dry-run] scrub Hyprspace lines from $file"
        return
    fi
    python3 - "$file" "$@" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
needles = sys.argv[2:]
text = path.read_text()
lines = text.splitlines(True)
filtered = [line for line in lines if not any(needle in line for needle in needles)]
if filtered == lines:
    raise SystemExit(0)
backup = path.with_name(path.name + '.hyprspace-cleanup.bak')
backup.write_text(text)
path.write_text(''.join(filtered))
PY
}

cleanup_sketchybar_hyprspace_block() {
    local file="$1"
    if [ ! -f "$file" ]; then
        return
    fi
    if [ "$APPLY" -eq 0 ]; then
        note "[dry-run] scrub Hyprspace Sketchybar block from $file"
        return
    fi
    python3 - "$file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
lines = text.splitlines(True)

start = None
end = None
for index, line in enumerate(lines):
    if line.strip() == 'sketchybar --add event hyprspace_workspace_change':
        start = index
        break

if start is None:
    raise SystemExit(0)

for index in range(start, len(lines)):
    line = lines[index]
    if 'sketchybar --trigger hyprspace_workspace_change' in line:
        end = index + 1
        break

if end is None:
    raise SystemExit('error: could not find end of Hyprspace Sketchybar block')

filtered = lines[:start] + lines[end:]
if filtered == lines:
    raise SystemExit(0)

backup = path.with_name(path.name + '.hyprspace-cleanup.bak')
backup.write_text(text)
path.write_text(''.join(filtered))
PY
}

cleanup_launch_agent() {
    local plist="$1"
    if [ -f "$plist" ]; then
        if [ "$APPLY" -eq 1 ]; then
            launchctl bootout "gui/$(id -u)" "$plist" >/dev/null 2>&1 || true
        else
            note "[dry-run] launchctl bootout gui/$(id -u) $plist"
        fi
        delete_path "$plist"
    fi
}

cleanup_brew_package() {
    local kind="$1"
    local name="$2"
    if ! command -v brew >/dev/null 2>&1; then
        return
    fi
    if [ "$kind" = cask ]; then
        if brew list --cask --versions "$name" >/dev/null 2>&1; then
            if [ "$APPLY" -eq 1 ]; then
                brew uninstall --zap --cask "$name" || brew uninstall --cask "$name" || true
            else
                note "[dry-run] brew uninstall --zap --cask $name"
            fi
        fi
    else
        if brew list --formula --versions "$name" >/dev/null 2>&1; then
            if [ "$APPLY" -eq 1 ]; then
                brew uninstall "$name" || true
            else
                note "[dry-run] brew uninstall $name"
            fi
        fi
    fi
}

cleanup_brew_tap() {
    local tap="$1"
    if [ "$REMOVE_TAP" -eq 0 ]; then
        return
    fi
    if ! command -v brew >/dev/null 2>&1; then
        return
    fi
    if brew tap | grep -qx "$tap"; then
        if [ "$APPLY" -eq 1 ]; then
            brew untap "$tap" || true
        else
            note "[dry-run] brew untap $tap"
        fi
    fi
}

stop_process() {
    local name="$1"
    if [ "$APPLY" -eq 1 ]; then
        killall "$name" >/dev/null 2>&1 || true
    else
        note "[dry-run] killall $name"
    fi
}

stop_brew_service() {
    local name="$1"
    if ! command -v brew >/dev/null 2>&1; then
        return
    fi
    if ! brew list --formula --versions "$name" >/dev/null 2>&1; then
        return
    fi
    if [ "$APPLY" -eq 1 ]; then
        brew services stop "$name" >/dev/null 2>&1 || true
    else
        note "[dry-run] brew services stop $name"
    fi
}

process_is_running() {
    local name="$1"
    pgrep -x "$name" >/dev/null 2>&1
}

print_running_process_details() {
    local name="$1"
    local pid
    while IFS= read -r pid; do
        [ -n "$pid" ] || continue
        ps -p "$pid" -o pid=,comm=,command=
    done < <(pgrep -x "$name" || true)
}

wait_for_managed_processes_exit() {
    local attempts=10
    local sleep_seconds=1
    local attempt
    local survivors=()
    local name

    if [ "$APPLY" -eq 0 ]; then
        return 0
    fi

    for attempt in $(seq 1 "$attempts"); do
        survivors=()
        for name in "${MANAGED_PROCESSES[@]}"; do
            if process_is_running "$name"; then
                survivors+=("$name")
            fi
        done

        if [ "${#survivors[@]}" -eq 0 ]; then
            note "[info] managed processes exited before post-clean snapshot"
            return 0
        fi

        if [ "$attempt" -lt "$attempts" ]; then
            note "[info] waiting for managed processes to exit: ${survivors[*]} (attempt $attempt/$attempts)"
            sleep "$sleep_seconds"
        fi
    done

    error "error: managed processes still running after cleanup attempts: ${survivors[*]}"
    for name in "${survivors[@]}"; do
        print_running_process_details "$name" >&2
    done
    return 1
}

note "== Hyprspace cleanup =="
note "mode: $([ "$APPLY" -eq 1 ] && echo APPLY || echo DRY-RUN)"
note "default cleanup scope: all proven Hyprspace traces, including local config artifacts after backup"
note "reset macOS defaults: $([ "$RESET_MACOS_DEFAULTS" -eq 1 ] && echo yes || echo no)"
note "config backup root: $SNAPSHOT_ROOT"

print_cleanup_state pre-cleanup

if [ -d "$HYPRSPACE_CONFIG_DIR" ]; then
    backup_hyprspace_config
else
    note "[info] config cleanup target absent: $HYPRSPACE_CONFIG_DIR"
fi

if [ -d "$SKETCHYBAR_CONFIG_DIR" ]; then
    backup_sketchybar_surface
else
    note "[info] sketchybar cleanup target absent: $SKETCHYBAR_CONFIG_DIR"
fi

note "-- Runtime process cleanup --"
stop_brew_service sketchybar
stop_brew_service borders
stop_process Hyprspace
stop_process AeroSpace
stop_process sketchybar
stop_process borders

HOME_DIR="$HOME"
BREW_PREFIX=""
if command -v brew >/dev/null 2>&1; then
    BREW_PREFIX="$(brew --prefix)"
fi

note "-- Homebrew packages --"
cleanup_brew_package cask hyprspace
cleanup_brew_package cask hyprspace-dev
cleanup_brew_package formula hyprspace
cleanup_brew_package formula hyprspace-dev
cleanup_brew_package cask aerospace
cleanup_brew_package cask aerospace-dev
cleanup_brew_package formula aerospace
cleanup_brew_package formula aerospace-dev
cleanup_brew_package formula sketchybar
cleanup_brew_package formula borders
cleanup_brew_tap dabvid/hyprspace

note "-- Core app/config/install traces --"
delete_path "/Applications/Hyprspace.app"
delete_path "/Applications/AeroSpace.app"
delete_path "$HOME_DIR/Applications/Hyprspace.app"
delete_path "$HOME_DIR/Applications/AeroSpace.app"
delete_path "$HOME_DIR/.config/hyprspace/config.toml"
delete_path "$HOME_DIR/.config/hyprspace/docs/default-config.toml"
delete_path "$HOME_DIR/.config/hyprspace/docs/README.md"
delete_path "$HOME_DIR/.config/hyprspace/docs/ACKNOWLEDGMENTS.md"
delete_path "$HOME_DIR/.config/hyprspace/docs"
delete_path "$HOME_DIR/.config/hyprspace"
delete_path "$HOME_DIR/.hyprspace.toml"
delete_path "$HOME_DIR/.aerospace.toml"
delete_path "$HOME_DIR/Library/Application Support/Hyprspace"
delete_path "$HOME_DIR/Library/Application Support/AeroSpace"
delete_path "$HOME_DIR/.config/aerospace"
delete_path "$HOME_DIR/.local/bin/hyprspace"
delete_path "$HOME_DIR/.local/bin/aerospace"
delete_path "$HOME_DIR/.local/libexec/hyprspace-cli"
delete_path "$HOME_DIR/.local/libexec/hyprspace-init"
delete_path_if_marked "$HOME_DIR/.local/devutils" \
    "$HOME_DIR/.local/devutils/setup-hyprspace-config.sh" \
    "$HOME_DIR/.local/devutils/setup-sketchybar-config.sh" \
    "$HOME_DIR/.local/devutils/setup-wallpaper.sh"
delete_path_if_marked "$HOME_DIR/.local/docs" \
    "$HOME_DIR/.local/docs/config.md" \
    "$HOME_DIR/.local/docs/installing-from-source.md"
delete_path_if_marked "$HOME_DIR/.local/configs" \
    "$HOME_DIR/.local/configs/sketchybar/sketchybarrc" \
    "$HOME_DIR/.local/configs/docs/README.md"
delete_path_if_marked "$HOME_DIR/.local/AeroSpace" \
    "$HOME_DIR/.local/AeroSpace/docs/config-examples/default-config.toml"

note "-- Shell completions and Homebrew-linked artifacts --"
if [ -n "$BREW_PREFIX" ]; then
    delete_path "$BREW_PREFIX/bin/hyprspace"
    delete_path "$BREW_PREFIX/bin/aerospace"
    delete_path "$BREW_PREFIX/share/zsh/site-functions/_hyprspace"
    delete_path "$BREW_PREFIX/share/zsh/site-functions/_aerospace"
    delete_path "$BREW_PREFIX/share/fish/vendor_completions.d/hyprspace.fish"
    delete_path "$BREW_PREFIX/share/fish/vendor_completions.d/aerospace.fish"
    delete_path "$BREW_PREFIX/etc/bash_completion.d/hyprspace"
    delete_path "$BREW_PREFIX/etc/bash_completion.d/aerospace"
    delete_path "$BREW_PREFIX/Caskroom/hyprspace"
    delete_path "$BREW_PREFIX/Caskroom/hyprspace-dev"
    delete_path "$BREW_PREFIX/Caskroom/aerospace"
    delete_path "$BREW_PREFIX/Caskroom/aerospace-dev"
    delete_path "$BREW_PREFIX/Cellar/hyprspace"
    delete_path "$BREW_PREFIX/Cellar/hyprspace-dev"
    delete_path "$BREW_PREFIX/Cellar/aerospace"
    delete_path "$BREW_PREFIX/Cellar/aerospace-dev"
fi
delete_path "$HOME_DIR/.local/share/zsh/site-functions/_hyprspace"
delete_path "$HOME_DIR/.local/share/zsh/site-functions/_aerospace"
delete_path "$HOME_DIR/.local/share/fish/vendor_completions.d/hyprspace.fish"
delete_path "$HOME_DIR/.local/share/fish/vendor_completions.d/aerospace.fish"
delete_path "$HOME_DIR/.local/etc/bash_completion.d/hyprspace"
delete_path "$HOME_DIR/.local/etc/bash_completion.d/aerospace"

note "-- Launch agents and runtime sockets --"
cleanup_launch_agent "$HOME_DIR/Library/LaunchAgents/peachlife.hyprspace.plist"
cleanup_launch_agent "$HOME_DIR/Library/LaunchAgents/dabvid.hyprspace.plist"
cleanup_launch_agent "$HOME_DIR/Library/LaunchAgents/hyprspace.plist"
cleanup_launch_agent "$HOME_DIR/Library/LaunchAgents/bobko.aerospace.plist"
cleanup_launch_agent "$HOME_DIR/Library/LaunchAgents/aerospace.plist"
delete_glob "/tmp/peachlife.hyprspace-*"
delete_glob "/tmp/dabvid.hyprspace-*"
delete_glob "/tmp/bobko.aerospace-*"
delete_path "/tmp/peachlife.hyprspace"
delete_path "/tmp/dabvid.hyprspace"
delete_path "/tmp/hyprspace"
delete_path "/tmp/Hyprspace"
delete_path "/tmp/aerospace"
delete_path "/tmp/AeroSpace"

note "-- Homebrew cache artifacts --"
delete_glob "$HOME_DIR/Library/Caches/Homebrew/downloads/*Hyprspace*"
delete_glob "$HOME_DIR/Library/Caches/Homebrew/downloads/*AeroSpace*"
delete_glob "$HOME_DIR/Library/Caches/Homebrew/Cask/*Hyprspace*"
delete_glob "$HOME_DIR/Library/Caches/Homebrew/Cask/*AeroSpace*"

note "-- Sketchybar integration traces --"
delete_path "$HOME_DIR/.config/sketchybar/sketchybarrc"
delete_path "$HOME_DIR/.config/sketchybar/plugins/auto_hide.sh"
delete_path "$HOME_DIR/.config/sketchybar/plugins/battery.sh"
delete_path "$HOME_DIR/.config/sketchybar/plugins/clock.sh"
delete_path "$HOME_DIR/.config/sketchybar/plugins/cpu.sh"
delete_path "$HOME_DIR/.config/sketchybar/plugins/disk_free.sh"
delete_path "$HOME_DIR/.config/sketchybar/plugins/docker_health.sh"
delete_path "$HOME_DIR/.config/sketchybar/plugins/front_app.sh"
delete_path "$HOME_DIR/.config/sketchybar/plugins/hyprspace_workspace.sh"
delete_path "$HOME_DIR/.config/sketchybar/plugins/ram.sh"
delete_path "$HOME_DIR/.config/sketchybar/helpers/cursor_monitor.swift"
delete_empty_dir "$HOME_DIR/.config/sketchybar/plugins"
delete_empty_dir "$HOME_DIR/.config/sketchybar/helpers"
delete_empty_dir "$HOME_DIR/.config/sketchybar"

if [ "$AGGRESSIVE" -eq 1 ]; then
    note "-- Aggressive incidental state cleanup --"
    delete_glob "$HOME_DIR/.local/state/**/*hyprspace*"
    delete_glob "$HOME_DIR/.local/share/**/*hyprspace*"
    delete_glob "$HOME_DIR/.local/run/**/*hyprspace*"
    delete_glob "$HOME_DIR/Library/Caches/**/*hyprspace*"
    delete_glob "$HOME_DIR/Library/Caches/**/*Hyprspace*"
    delete_glob "$HOME_DIR/Library/Preferences/*hyprspace*"
    delete_glob "$HOME_DIR/Library/Preferences/*Hyprspace*"
    delete_glob "$HOME_DIR/Library/Preferences/*peachlife.hyprspace*"
    delete_glob "$HOME_DIR/Library/Saved Application State/**/*hyprspace*"
    delete_glob "$HOME_DIR/Library/Saved Application State/**/*Hyprspace*"
fi

if [ "$RESET_MACOS_DEFAULTS" -eq 1 ]; then
    note "-- Best-effort macOS defaults reset --"
    if [ "$APPLY" -eq 1 ]; then
        defaults delete com.apple.spaces spans-displays >/dev/null 2>&1 || true
        defaults delete com.apple.dock expose-group-apps >/dev/null 2>&1 || true
        defaults delete -g NSAutomaticWindowAnimationsEnabled >/dev/null 2>&1 || true
        killall SystemUIServer >/dev/null 2>&1 || true
        killall Dock >/dev/null 2>&1 || true
    else
        note "[dry-run] defaults delete com.apple.spaces spans-displays"
        note "[dry-run] defaults delete com.apple.dock expose-group-apps"
        note "[dry-run] defaults delete -g NSAutomaticWindowAnimationsEnabled"
        note "[dry-run] killall SystemUIServer"
        note "[dry-run] killall Dock"
    fi
fi

wait_for_managed_processes_exit

print_cleanup_state post-cleanup

note "== Done =="
if [ "$APPLY" -eq 0 ]; then
    note "No files were removed. Re-run with --apply to execute the cleanup."
fi
