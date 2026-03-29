#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
install_prefix="${1:-$root_dir/.local-install-test}"
target_home="${2:-$root_dir/.local-installed-init-home-manual}"
runtime="$install_prefix/libexec/hyprspace-init/hyprspace-init"

if [ ! -x "$runtime" ]; then
    echo "ERROR: missing installed init runtime at $runtime" >&2
    echo "Run: bgtail bash ./tests/test-hyprspace-local-install.sh" >&2
    exit 1
fi

rm -rf "$target_home"

echo "[info] install_prefix=$install_prefix"
echo "[info] target_home=$target_home"
echo "[step] running installed hyprspace init runtime"
export HYPRSPACE_HOME_OVERRIDE="$target_home"
export HYPRSPACE_SKIP_DEPENDENCY_SETUP=1
export HYPRSPACE_SKIP_MACOS_DEFAULTS=1
export HYPRSPACE_SKIP_SKETCHYBAR_SERVICE=1
bash -lc "cd \"$root_dir\" && \"$runtime\""

echo "[info] generated files under $target_home"
if [ -d "$target_home" ]; then
    /usr/bin/find "$target_home" -print | /usr/bin/sort
else
    echo "[warn] no files were created under $target_home"
fi
