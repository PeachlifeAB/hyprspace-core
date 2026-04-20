#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
source "$root_dir/tests/_common.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
test_root="$(make_temp_dir)"
test_home="$(make_temp_dir)"
register_cleanup_path "$test_root" "$test_home"
trap cleanup_paths_on_exit EXIT

app_root="$test_root/Hyprspace.app"
resources_dir="$app_root/Contents/Resources"
runtime_dir="$app_root/Contents/Resources/libexec/hyprspace-init"
fake_bin="$test_root/bin"
actions_log="$test_root/post-actions.log"

mkdir -p "$runtime_dir" "$fake_bin" "$app_root/Contents/MacOS" "$test_home"
cp -R "$root_dir/libexec/hyprspace-init/." "$runtime_dir/"
chmod +x "$runtime_dir/hyprspace-init" "$runtime_dir/apply-init-selections.sh"
mkdir -p "$resources_dir/AeroSpace/docs"
cp -R "$root_dir/AeroSpace/docs/config-examples" "$resources_dir/AeroSpace/docs/config-examples"
cp -R "$root_dir/scripts" "$resources_dir/scripts"
cp -R "$root_dir/artifacts" "$resources_dir/artifacts"
chmod +x "$resources_dir/scripts/internal/setup-wallpaper.sh"

cat >"$fake_bin/open" <<EOF
#!/bin/bash
echo "open \$*" >>"$actions_log"
EOF

cat >"$fake_bin/pgrep" <<'EOF'
#!/bin/bash
if [ "${1:-}" = "-x" ] && [ "${2:-}" = "Hyprspace" ]; then
    exit 0
fi
exit 1
EOF

cat >"$fake_bin/sketchybar" <<EOF
#!/bin/bash
echo "sketchybar \$*" >>"$actions_log"
EOF

chmod +x "$fake_bin/open" "$fake_bin/pgrep" "$fake_bin/sketchybar"

echo "[step] running hyprspace init in default-apply mode and capturing post-actions"
PATH="$fake_bin:$PATH" \
    HYPRSPACE_HOME_OVERRIDE="$test_home" \
    HYPRSPACE_SKIP_DEPENDENCY_SETUP=1 \
    HYPRSPACE_SKIP_MACOS_DEFAULTS=1 \
    HYPRSPACE_SKIP_SKETCHYBAR_SERVICE=1 \
    HYPRSPACE_SKIP_WALLPAPER_SETUP=1 \
    HYPRSPACE_INIT_ASSUME_DEFAULTS=1 \
    bash "$runtime_dir/hyprspace-init"

echo "[step] asserting post-actions"
grep -q '^open '"$app_root"'$' "$actions_log"
grep -q '^sketchybar --reload$' "$actions_log"

open_line="$(grep -n '^open '"$app_root"'$' "$actions_log" | cut -d: -f1)"
reload_line="$(grep -n '^sketchybar --reload$' "$actions_log" | cut -d: -f1)"
if [ "$open_line" -ge "$reload_line" ]; then
    echo "[error] sketchybar reload ran before app launch"
    cat "$actions_log"
    exit 1
fi

echo "[ok] hyprspace init post-actions test passed"
