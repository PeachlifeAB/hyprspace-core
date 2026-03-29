#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
source "$root_dir/tests/_common.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
require_opt_in RUN_WALLPAPER_TESTS "test-hyprspace-init-wallpaper.sh changes the live desktop wallpaper and restores it afterward."
log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-init-wallpaper.log"
fake_install_root="$(make_temp_dir)"
fake_wrapper="$fake_install_root/hyprspace"
fake_runtime_dir="$fake_install_root/libexec/hyprspace-init"
test_home="$(make_temp_dir)"
wallpaper_probe_dir="$(make_temp_dir)"
wallpaper_before_json="$wallpaper_probe_dir/wallpaper-before.json"
wallpaper_after_json="$wallpaper_probe_dir/wallpaper-after.json"
test_wallpaper="$wallpaper_probe_dir/hyprspace-wallpaper-test.jpg"

read_wallpaper_json() {
    /usr/bin/swift - <<'SWIFT'
import AppKit
import Foundation

let workspace = NSWorkspace.shared
let screens = NSScreen.screens
if screens.isEmpty {
    fputs("[]\n", stderr)
    exit(1)
}

let paths = screens.compactMap { screen in
    workspace.desktopImageURL(for: screen)?.path
}

if paths.count != screens.count {
    fputs("[]\n", stderr)
    exit(2)
}

let data = try JSONSerialization.data(withJSONObject: paths, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data("\n".utf8))
SWIFT
}

restore_wallpaper_state() {
    if [ ! -f "$wallpaper_before_json" ]; then
        return 0
    fi

    WALLPAPER_STATE_JSON="$wallpaper_before_json" /usr/bin/swift - <<'SWIFT'
import AppKit
import Foundation

let statePath = ProcessInfo.processInfo.environment["WALLPAPER_STATE_JSON"]!
let data = try Data(contentsOf: URL(fileURLWithPath: statePath))
let paths = try JSONSerialization.jsonObject(with: data) as! [String]
let workspace = NSWorkspace.shared
let screens = NSScreen.screens

for (screen, path) in zip(screens, paths) {
    let options = workspace.desktopImageOptions(for: screen) ?? [:]
    try workspace.setDesktopImageURL(URL(fileURLWithPath: path), for: screen, options: options)
}
SWIFT
}

cleanup_wallpaper_test() {
    echo "[cleanup] restoring wallpaper state"
    restore_wallpaper_state || true
}

mkdir -p "$log_dir"
register_cleanup_path "$fake_install_root" "$test_home" "$wallpaper_probe_dir"
trap 'status=$?; cleanup_wallpaper_test; cleanup_paths_on_exit; exit $status' EXIT INT TERM
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] log_file=$log_file"
echo "[info] fake_install_root=$fake_install_root"
echo "[info] test_home=$test_home"
echo "[info] wallpaper_before_json=$wallpaper_before_json"
echo "[info] test_wallpaper=$test_wallpaper"

if [[ ! -d "$root_dir/AeroSpace/docs/config-examples" ]]; then
    echo "[prereq] patched AeroSpace checkout not found or incomplete at $root_dir/AeroSpace"
    echo "[prereq] Run ./scripts/patch/refresh-workspace.sh first."
    exit 1
fi

if ! command -v osascript >/dev/null 2>&1; then
    echo "[prereq] osascript is required for wallpaper application"
    exit 1
fi

echo "[step] capturing current wallpaper state"
if ! read_wallpaper_json >"$wallpaper_before_json"; then
    echo "[skip] could not read current wallpaper state; desktop session may be unavailable or locked"
    exit 0
fi
cat "$wallpaper_before_json"

echo "[step] creating unique wallpaper probe image"
cp "$root_dir/artifacts/gfx/wallpaper-default.jpg" "$test_wallpaper"
ls -l "$test_wallpaper"

mkdir -p "$fake_install_root/libexec"
cp -R "$root_dir/libexec/hyprspace-init" "$fake_runtime_dir"
"$root_dir/scripts/internal/build-init-helpers.sh" "$fake_runtime_dir"
chmod +x "$fake_runtime_dir/hyprspace-init" "$fake_runtime_dir/apply-init-selections.sh"
cp -R "$root_dir/scripts" "$fake_install_root/scripts"
cp -R "$root_dir/artifacts" "$fake_install_root/artifacts"
chmod +x "$fake_install_root/scripts/internal/setup-wallpaper.sh"
mkdir -p "$fake_install_root/AeroSpace/docs" "$fake_install_root/bin"
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

echo "[step] running packaged hyprspace init with wallpaper enabled via symlinked entrypoint"
output="$(HYPRSPACE_HOME_OVERRIDE="$test_home" HYPRSPACE_SKIP_DEPENDENCY_SETUP=1 HYPRSPACE_SKIP_MACOS_DEFAULTS=1 HYPRSPACE_SKIP_SKETCHYBAR_SERVICE=1 HYPRSPACE_WALLPAPER_PATH="$test_wallpaper" HYPRSPACE_INIT_ASSUME_DEFAULTS=1 bash "$fake_install_root/bin/hyprspace" init 2>&1)"
printf '%s\n' "$output"

echo "[step] capturing wallpaper state after init"
if ! read_wallpaper_json >"$wallpaper_after_json"; then
    echo "[error] failed to read wallpaper state after init"
    exit 1
fi
cat "$wallpaper_after_json"

echo "[step] asserting all screens now point to the unique test wallpaper path"
WALLPAPER_AFTER_JSON="$wallpaper_after_json" TEST_WALLPAPER_PATH="$test_wallpaper" python3 - <<'PY'
import json
import os

with open(os.environ["WALLPAPER_AFTER_JSON"], "r", encoding="utf-8") as handle:
    after = json.load(handle)

expected = os.environ["TEST_WALLPAPER_PATH"]
assert after, "no wallpaper paths were captured"
assert all(path == expected for path in after), f"expected every wallpaper path to be {expected}, got {after}"
PY

echo "[ok] hyprspace init wallpaper test passed"
