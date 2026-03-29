#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
source "$root_dir/tests/_common.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-init-notty.log"
fake_install_root="$(make_temp_dir)"
fake_wrapper="$fake_install_root/hyprspace"
fake_runtime_dir="$fake_install_root/libexec/hyprspace-init"
test_home="$(make_temp_dir)"

mkdir -p "$log_dir"
register_cleanup_path "$fake_install_root" "$test_home"
trap cleanup_paths_on_exit EXIT
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] log_file=$log_file"
echo "[info] fake_install_root=$fake_install_root"
echo "[info] test_home=$test_home"

if [[ ! -d "$root_dir/AeroSpace/docs/config-examples" ]]; then
    echo "[prereq] patched AeroSpace checkout not found or incomplete at $root_dir/AeroSpace"
    echo "[prereq] Run ./scripts/patch/refresh-workspace.sh first."
    exit 1
fi

mkdir -p "$fake_install_root/libexec" "$fake_install_root/bin"
cp -R "$root_dir/libexec/hyprspace-init" "$fake_runtime_dir"
chmod +x "$fake_runtime_dir/hyprspace-init" "$fake_runtime_dir/apply-init-selections.sh"
cp -R "$root_dir/scripts" "$fake_install_root/scripts"
cp -R "$root_dir/artifacts" "$fake_install_root/artifacts"
chmod +x "$fake_install_root/scripts/internal/setup-wallpaper.sh"
mkdir -p "$fake_install_root/AeroSpace/docs"
cp -R "$root_dir/AeroSpace/docs/config-examples" "$fake_install_root/AeroSpace/docs/config-examples"
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

if [ "${1:-}" = "init" ]; then
    shift
    exec "$root_dir/libexec/hyprspace-init/hyprspace-init" "$@"
fi

exec "$root_dir/libexec/hyprspace-cli" "$@"
EOF
chmod +x "$fake_wrapper"
ln -s "$fake_wrapper" "$fake_install_root/bin/hyprspace"

echo "[step] running packaged hyprspace init without a tty in default-apply mode via symlinked entrypoint"
if ! output="$(HYPRSPACE_HOME_OVERRIDE="$test_home" HYPRSPACE_SKIP_DEPENDENCY_SETUP=1 HYPRSPACE_SKIP_MACOS_DEFAULTS=1 HYPRSPACE_SKIP_SKETCHYBAR_SERVICE=1 HYPRSPACE_SKIP_WALLPAPER_SETUP=1 HYPRSPACE_INIT_ASSUME_DEFAULTS=1 bash "$fake_install_root/bin/hyprspace" init 2>&1)"; then
    echo "[error] packaged hyprspace init default-apply mode failed"
    printf '%s\n' "$output"
    exit 1
fi

echo "[step] command output follows"
printf '%s\n' "$output"
test -f "$test_home/.config/hyprspace/config.toml"
test -f "$test_home/.config/hyprspace/docs/default-config.toml"
test -f "$test_home/.config/hyprspace/docs/README.md"
test -f "$test_home/.config/hyprspace/docs/ACKNOWLEDGMENTS.md"
test -f "$test_home/.config/sketchybar/sketchybarrc"
echo "[ok] hyprspace init non-tty default-apply test passed"
