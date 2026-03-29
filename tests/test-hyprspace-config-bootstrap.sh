#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
source "$root_dir/tests/_common.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
test_home="$(make_temp_dir)"
register_cleanup_path "$test_home"
trap cleanup_paths_on_exit EXIT

echo "[step] injecting default Hyprspace config files"
HYPRSPACE_HOME_OVERRIDE="$test_home" "$root_dir/scripts/internal/setup-hyprspace-config.sh"

echo "[step] injecting default Sketchybar config files"
HYPRSPACE_HOME_OVERRIDE="$test_home" HYPRSPACE_SKIP_SKETCHYBAR_SERVICE=1 "$root_dir/scripts/internal/setup-sketchybar-config.sh"

echo "[step] asserting injected files"
test -f "$test_home/.config/hyprspace/config.toml"
test -f "$test_home/.config/hyprspace/docs/default-config.toml"
test -f "$test_home/.config/hyprspace/docs/README.md"
test -f "$test_home/.config/hyprspace/docs/ACKNOWLEDGMENTS.md"
echo "[step] asserting old flat paths do not exist"
test ! -f "$test_home/.config/hyprspace/config.default.toml"
test ! -f "$test_home/.config/hyprspace/README.md"
test -f "$test_home/.config/sketchybar/sketchybarrc"
test -x "$test_home/.config/sketchybar/plugins/hyprspace_workspace.sh"

echo "[step] preserving an existing Hyprspace active config"
printf '%s\n' '# preserve me' >"$test_home/.config/hyprspace/config.toml"
HYPRSPACE_HOME_OVERRIDE="$test_home" "$root_dir/scripts/internal/setup-hyprspace-config.sh"
grep -q '^# preserve me$' "$test_home/.config/hyprspace/config.toml"

echo "[step] preserving an existing Sketchybar config"
printf '%s\n' '# preserve sketchybar' >"$test_home/.config/sketchybar/sketchybarrc"
HYPRSPACE_HOME_OVERRIDE="$test_home" HYPRSPACE_SKIP_SKETCHYBAR_SERVICE=1 "$root_dir/scripts/internal/setup-sketchybar-config.sh"
grep -q '^# preserve sketchybar$' "$test_home/.config/sketchybar/sketchybarrc"

echo "[step] repairing a preserved but broken Sketchybar config"
cat >"$test_home/.config/sketchybar/sketchybarrc" <<'EOF'
#!/bin/bash
# preserve sketchybar
PLUGIN_DIR="$CONFIG_DIR/plugins"
HYPRSPACE_BIN="${HYPRSPACE_BIN:-$HOME/.local/bin/hyprspace}"

##### Adding Hyprspace Workspace Indicators #####
# Add Hyprspace-backed workspace items (not Mission Control spaces).
# These will highlight the focused Hyprspace workspace and focus workspaces on click.

for sid in $("$HYPRSPACE_BIN" list-workspaces --all 2>/dev/null); do
    space=(
        icon="$sid"
        background.color=0x40ffffff
        background.corner_radius=5
        background.height=25
        background.position=center
        label.position=center
        click_script="$HYPRSPACE_BIN workspace $sid"
    )
    sketchybar --add item space."$sid" left \
        --set space."$sid" "${space[@]}" \
done

# Initial highlight on startup
focused="$("$HYPRSPACE_BIN" list-workspaces --focused 2>/dev/null)"

##### Auto-Hide Workaround (macOS Menu Bar) #####
EOF
rm -f "$test_home/.config/sketchybar/plugins/hyprspace_workspace.sh"
HYPRSPACE_HOME_OVERRIDE="$test_home" HYPRSPACE_SKIP_SKETCHYBAR_SERVICE=1 "$root_dir/scripts/internal/setup-sketchybar-config.sh"
grep -q '^# preserve sketchybar$' "$test_home/.config/sketchybar/sketchybarrc"
test -x "$test_home/.config/sketchybar/plugins/hyprspace_workspace.sh"
grep -q 'sketchybar --add event hyprspace_workspace_change' "$test_home/.config/sketchybar/sketchybarrc"
grep -q 'script="\$PLUGIN_DIR/hyprspace_workspace.sh"' "$test_home/.config/sketchybar/sketchybarrc"
grep -q -- '--subscribe space."\$sid" hyprspace_workspace_change' "$test_home/.config/sketchybar/sketchybarrc"
grep -q 'sketchybar --trigger hyprspace_workspace_change FOCUSED_WORKSPACE="\$focused"' "$test_home/.config/sketchybar/sketchybarrc"

echo "[ok] hyprspace config bootstrap test passed"
