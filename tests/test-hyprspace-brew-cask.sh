#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
checkout_dir="$root_dir/AeroSpace"
source "$root_dir/tests/_common.sh"
source "$root_dir/scripts/verify/repo-state-table.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
require_opt_in RUN_INTEGRATION_TESTS "test-hyprspace-brew-cask.sh is in the integration tier."
log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-brew-cask.log"
build_version="$(cat "$root_dir/version.txt")"
zip_name="Hyprspace-v${build_version}.zip"
cask_file="$checkout_dir/.release/hyprspace.rb"
tapped_cask_file="/opt/homebrew/Library/Taps/peachlifeab/homebrew-tap/Casks/hyprspace.rb"
tap_backup_dir=""

mkdir -p "$log_dir"
exec > >(tee "$log_file") 2>&1

cleanup() {
    if [[ -n "$tap_backup_dir" && -f "$tap_backup_dir/hyprspace.rb" ]]; then
        cp "$tap_backup_dir/hyprspace.rb" "$tapped_cask_file"
        echo "[cleanup] restored tapped cask from backup"
    fi

    cleanup_paths_on_exit
}

brew_cask_on_exit() {
    print_repo_state_table brew-cask-final \
        source "$root_dir" \
        tap "$root_dir/../../homebrew-tap" \
        releases "$root_dir/../hyprspace-releases"
    cleanup
}

trap brew_cask_on_exit EXIT

echo "[info] root_dir=$root_dir"
echo "[info] build_version=$build_version"
echo "[info] zip_name=$zip_name"
echo "[info] log_file=$log_file"
print_repo_state_table brew-cask-preflight \
    source "$root_dir" \
    tap "$root_dir/../../homebrew-tap" \
    releases "$root_dir/../hyprspace-releases"

if [[ ! -d "$checkout_dir" ]]; then
    echo "[prereq] patched AeroSpace checkout not found at $checkout_dir"
    echo "[prereq] Run ./scripts/patch/refresh-workspace.sh first."
    exit 1
fi

if [[ ! -f "$tapped_cask_file" ]]; then
    echo "[prereq] tapped cask not found at $tapped_cask_file"
    exit 1
fi

# Step 1: generate the cask from a local file URI so the test is isolated
echo "[step] building release artifacts"
cd "$checkout_dir"
./script/internal/build-release.sh --skip-docs --skip-shell-parser --allow-dirty --codesign-identity -

echo "[step] generating cask from local release artifact"
local_zip="$checkout_dir/.release/${zip_name}"
resolved_zip="$(resolve_path "$local_zip")"
test -f "$local_zip"
./script/build-brew-cask.sh \
    --cask-name hyprspace \
    --zip-uri "file://${resolved_zip}" \
    --build-version "$build_version"

test -f "$cask_file"

# Step 2: cask is valid Ruby
echo "[step] checking cask is valid Ruby"
ruby -c "$cask_file"

# Step 3: SHA in cask matches the release zip
echo "[step] verifying cask SHA matches release zip"
cask_sha="$(grep 'sha256' "$cask_file" | awk '{print $2}' | tr -d '"')"
zip_sha="$(shasum -a 256 "$local_zip" | awk '{print $1}')"
echo "[info] cask_sha=$cask_sha"
echo "[info] zip_sha=$zip_sha"
test "$cask_sha" = "$zip_sha"

echo "[step] running brew style"
brew style "$cask_file"

echo "[step] verifying cask caveats"
grep -Fq "Run 'hyprspace init' to start the setup wizard." "$cask_file"
grep -Fq "Hyprspace.app was installed to /Applications." "$cask_file"
grep -Fq 'depends_on formula: "gum"' "$cask_file"

echo "[step] running brew audit --cask (offline)"
local_audit_dir="$(make_temp_dir)"
register_cleanup_path "$local_audit_dir"
local_audit_cask_file="$local_audit_dir/hyprspace.rb"
cp "$cask_file" "$local_audit_cask_file"
python3 - "$local_audit_cask_file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
text = text.replace(',\n      verified: "github.com/PeachlifeAB/hyprspace-releases/"', '')
path.write_text(text)
PY
tap_backup_dir="$(make_temp_dir)"
register_cleanup_path "$tap_backup_dir"
cp "$tapped_cask_file" "$tap_backup_dir/hyprspace.rb"
echo "[info] tapped_cask_file=$tapped_cask_file"
echo "[info] tap_backup_dir=$tap_backup_dir"
echo "[info] local_audit_cask_file=$local_audit_cask_file"
cp "$local_audit_cask_file" "$tapped_cask_file"
HOMEBREW_NO_INSTALL_FROM_API=1 brew audit --cask peachlifeab/tap/hyprspace

echo "[ok] hyprspace brew cask test passed"
