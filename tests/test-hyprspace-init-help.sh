#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
source "$root_dir/tests/_common.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-init-help.log"
fake_install_root="$(make_temp_dir)"
fake_wrapper="$fake_install_root/hyprspace"
fake_runtime_dir="$fake_install_root/libexec/hyprspace-init"

mkdir -p "$log_dir"
register_cleanup_path "$fake_install_root"
trap cleanup_paths_on_exit EXIT
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] log_file=$log_file"
echo "[info] fake_install_root=$fake_install_root"

if [[ ! -d "$root_dir/libexec/hyprspace-init" ]]; then
    echo "[prereq] init runtime not found at $root_dir/libexec/hyprspace-init"
    exit 1
fi

mkdir -p "$fake_install_root/libexec" "$fake_install_root/bin"
cp -R "$root_dir/libexec/hyprspace-init" "$fake_runtime_dir"
chmod +x "$fake_runtime_dir/hyprspace-init" "$fake_runtime_dir/apply-init-selections.sh"
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

echo "[step] running packaged hyprspace init wrapper in runtime-info mode via symlinked entrypoint"
if ! output="$(HYPRSPACE_INIT_TEST_MODE=runtime "$fake_install_root/bin/hyprspace" init 2>&1)"; then
    echo "[error] packaged hyprspace init wrapper failed"
    printf '%s\n' "$output"
    exit 1
fi

echo "[step] command output follows"
printf '%s\n' "$output"
grep -q '"runtime_root":' <<<"$output" || {
    echo "[fail] runtime_root missing from init wrapper output"
    exit 1
}
grep -q '"apply_script_exists": true' <<<"$output" || {
    echo "[fail] apply_script_exists missing from init wrapper output"
    exit 1
}
echo "[ok] hyprspace init wrapper surface test passed"
