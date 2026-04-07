#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
source "$root_dir/tests/_common.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-deinit-surface.log"
fake_install_root="$(make_temp_dir)"
fake_wrapper="$fake_install_root/hyprspace"
fake_runtime_dir="$fake_install_root/libexec/hyprspace-deinit"
test_home="$(make_temp_dir)"

mkdir -p "$log_dir"
register_cleanup_path "$fake_install_root" "$test_home"
trap cleanup_paths_on_exit EXIT
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] log_file=$log_file"
echo "[info] fake_install_root=$fake_install_root"
echo "[info] test_home=$test_home"

if [[ ! -d "$root_dir/libexec/hyprspace-deinit" ]]; then
    echo "[prereq] deinit runtime not found at $root_dir/libexec/hyprspace-deinit"
    exit 1
fi

mkdir -p "$fake_install_root/libexec" "$fake_install_root/bin"
cp -R "$root_dir/libexec/hyprspace-deinit" "$fake_runtime_dir"
chmod +x "$fake_runtime_dir/hyprspace-deinit" "$fake_runtime_dir/apply-deinit-selections.sh"
ln -s /usr/bin/true "$fake_install_root/libexec/hyprspace-cli"

cat >"$fake_wrapper" <<'EOF'
#!/bin/bash
set -euo pipefail

resolve_real_path() {
    local source="${BASH_SOURCE[0]:-$1}"
    while [[ -L "$source" ]]; do
        local dir
        dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ "$source" != /* ]] && source="$dir/$source"
    done
    printf '%s\n' "$(cd -P "$(dirname "$source")" && pwd)/$(basename "$source")"
}

script_path="$(resolve_real_path "$0")"
script_dir="$(cd -P "$(dirname "$script_path")" && pwd)"
if [ -x "$script_dir/libexec/hyprspace-cli" ]; then
    root_dir="$script_dir"
elif [ -x "$script_dir/../libexec/hyprspace-cli" ]; then
    root_dir="$(cd "$script_dir/.." && pwd)"
else
    echo "ERROR: missing packaged hyprspace CLI runtime" >&2
    exit 1
fi

if [ "${1:-}" = "deinit" ]; then
    shift
    exec "$root_dir/libexec/hyprspace-deinit/hyprspace-deinit" "$@"
fi

exec "$root_dir/libexec/hyprspace-cli" "$@"
EOF
chmod +x "$fake_wrapper"
ln -s "$fake_wrapper" "$fake_install_root/bin/hyprspace"

echo "[step] runtime-info packaged wrapper check"
output="$(HYPRSPACE_DEINIT_TEST_MODE=runtime "$fake_install_root/bin/hyprspace" deinit 2>&1)"
printf '%s\n' "$output"
grep -q '"runtime_root":' <<<"$output" || die "[fail] runtime_root missing from deinit wrapper output"
grep -q '"apply_script_exists": true' <<<"$output" || die "[fail] apply_script_exists missing from deinit wrapper output"

echo "[step] defaults test mode returns all step keys"
output="$(HYPRSPACE_DEINIT_TEST_MODE=defaults "$fake_install_root/bin/hyprspace" deinit 2>&1)"
printf '%s\n' "$output"
grep -q '"sketchybar"' <<<"$output" || die "[fail] sketchybar missing from defaults"
grep -q '"borders"' <<<"$output" || die "[fail] borders missing from defaults"
grep -q '"hyprspace_config"' <<<"$output" || die "[fail] hyprspace_config missing from defaults"
grep -q '"wallpaper"' <<<"$output" || die "[fail] wallpaper missing from defaults"
grep -q '"macos_defaults"' <<<"$output" || die "[fail] macos_defaults missing from defaults"
grep -q '"homebrew_tap"' <<<"$output" || die "[fail] homebrew_tap missing from defaults"

echo "[step] selection-preview with subset"
output="$(HYPRSPACE_DEINIT_TEST_SELECTIONS="sketchybar,borders" HYPRSPACE_DEINIT_TEST_MODE=selection-preview "$fake_install_root/bin/hyprspace" deinit 2>&1)"
printf '%s\n' "$output"
grep -q '"sketchybar"' <<<"$output" || die "[fail] sketchybar missing from selection-preview"
grep -q '"borders"' <<<"$output" || die "[fail] borders missing from selection-preview"

echo "[step] help flag works"
output="$("$fake_install_root/bin/hyprspace" deinit --help 2>&1)"
printf '%s\n' "$output"
grep -q 'Interactive teardown' <<<"$output" || die "[fail] help text missing"

echo "[ok] hyprspace deinit surface test passed"
