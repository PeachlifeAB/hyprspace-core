#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
source "$root_dir/tests/_common.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-update-surface.log"
fake_install_root="$(make_temp_dir)"
fake_wrapper="$fake_install_root/hyprspace"
fake_runtime_dir="$fake_install_root/libexec/hyprspace-update"
test_home="$(make_temp_dir)"

mkdir -p "$log_dir"
register_cleanup_path "$fake_install_root" "$test_home"
trap cleanup_paths_on_exit EXIT
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] log_file=$log_file"
echo "[info] fake_install_root=$fake_install_root"
echo "[info] test_home=$test_home"

mkdir -p "$fake_install_root/libexec" "$fake_install_root/bin"
cp -R "$root_dir/libexec/hyprspace-update" "$fake_runtime_dir"
chmod +x "$fake_runtime_dir/hyprspace-update"
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

if [ "${1:-}" = "update" ]; then
    shift
    exec "$root_dir/libexec/hyprspace-update/hyprspace-update" "$@"
fi

exec "$root_dir/libexec/hyprspace-cli" "$@"
EOF
chmod +x "$fake_wrapper"
ln -s "$fake_wrapper" "$fake_install_root/bin/hyprspace"

echo "[step] runtime-info packaged wrapper check"
output="$(HYPRSPACE_HOME_OVERRIDE="$test_home" HYPRSPACE_UPDATE_TEST_MODE=runtime "$fake_install_root/bin/hyprspace" update)"
printf '%s\n' "$output"
grep -q '"runtime_root":' <<<"$output" || die "[fail] runtime_root missing"

echo "[step] no-issue path"
output="$(HYPRSPACE_HOME_OVERRIDE="$test_home" "$fake_install_root/bin/hyprspace" update)"
printf '%s\n' "$output"
grep -q 'No known issues found.' <<<"$output" || die "[fail] no-issue message missing"

echo "[step] decline path remains read-only"
mkdir -p "$test_home"
printf '%s\n' fixture >"$test_home/.hyprspace-update-fixture"
decline_output="$(printf 'n\n' | HYPRSPACE_HOME_OVERRIDE="$test_home" "$fake_install_root/bin/hyprspace" update)"
printf '%s\n' "$decline_output"
grep -q 'Skipped fixture issue.' <<<"$decline_output" || die "[fail] skip message missing"
test ! -f "$test_home/.config/hyprspace/fixture-applied" || die "[fail] fixture applied on decline"
test ! -d "$test_home/.config/hyprspace/.backups" || die "[fail] backup created on decline"

echo "[step] accept path creates backup and applies fix"
accept_output="$(printf 'y\n' | HYPRSPACE_HOME_OVERRIDE="$test_home" "$fake_install_root/bin/hyprspace" update)"
printf '%s\n' "$accept_output"
test -f "$test_home/.config/hyprspace/fixture-applied" || die "[fail] fixture-applied missing"
grep -q 'fixture fixed' "$test_home/.config/hyprspace/fixture-applied" || die "[fail] fixture-applied content incorrect"
backup_root="$test_home/.config/hyprspace/.backups"
test -d "$backup_root" || die "[fail] backup root missing"
grep -q 'Backup location:' <<<"$accept_output" || die "[fail] backup location not reported"

echo "[ok] hyprspace update surface test passed"
