#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
checkout_dir="$root_dir/AeroSpace"
printf '%s\n' "[entry] pwd -L=$(pwd)"
printf '%s\n' "[entry] pwd -P=$(pwd -P)"
printf '%s\n' "[entry] script=$0"
printf '%s\n' "[entry] bash_source=${BASH_SOURCE[0]}"
printf '%s\n' "[entry] root_dir=$root_dir"
printf '%s\n' "[entry] checkout_dir=$checkout_dir"
printf '%s\n' "[entry] common=$root_dir/tests/_common.sh"
printf '%s\n' "[entry] RUN_INTEGRATION_TESTS=${RUN_INTEGRATION_TESTS:-0}"
printf '%s\n' "[entry] listing root_dir"
ls -ld "$root_dir"
printf '%s\n' "[entry] listing common"
ls -ld "$root_dir/tests/_common.sh"
printf '%s\n' "[entry] listing checkout_dir"
ls -ld "$checkout_dir"
printf '%s\n' "[entry] listing .release"
ls -ld "$checkout_dir/.release" 2>/dev/null || true
source "$root_dir/tests/_common.sh"

declare -a HYPRSPACE_TEST_CLEANUP_PATHS=()
if [[ "${RUN_INTEGRATION_TESTS:-0}" != "1" ]]; then
    echo "[error] RUN_INTEGRATION_TESTS=1 is required for test-hyprspace-release-build.sh" >&2
    exit 1
fi
log_dir="$root_dir/log/build"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-release-build.log"
build_version="$(cat "$root_dir/version.txt")"

printf '%s\n' "[entry] build_version=$build_version"
printf '%s\n' "[entry] listing concrete zip target"
ls -ld "$checkout_dir/.release" "$checkout_dir/.release/Hyprspace-v${build_version}.zip" 2>/dev/null || true

mkdir -p "$log_dir"
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] checkout_dir=$checkout_dir"
echo "[info] log_file=$log_file"
echo "[info] build_version=$build_version"

if [[ ! -d "$checkout_dir" ]]; then
    echo "[prereq] patched AeroSpace checkout not found at $checkout_dir"
    echo "[prereq] Run ./scripts/patch/refresh-workspace.sh first."
    exit 1
fi

cd "$checkout_dir"

echo "[step] running internal release builder with local dev settings"
source "$root_dir/product.conf"
sign_id="$HYPRSPACE_CODESIGN_IDENTITY"
if [[ "$sign_id" != "-" ]] && ! security find-identity -v -p codesigning | grep -Fq "\"$sign_id\""; then
    echo "[info] signing identity not found: $sign_id — falling back to adhoc signing (-)"
    sign_id="-"
fi
./script/internal/build-release.sh --build-version "$build_version" --skip-docs --skip-shell-parser --allow-dirty --codesign-identity "$sign_id"

echo "[step] asserting release artifacts"
test -d .release/Hyprspace.app
test -f .release/hyprspace
test -x .release/libexec/hyprspace-init/hyprspace-init
test -x .release/Hyprspace-v${build_version}/libexec/hyprspace-init/hyprspace-init
test -f .release/artifacts/gfx/wallpaper-default.jpg
test -f .release/Hyprspace-v${build_version}/artifacts/gfx/wallpaper-default.jpg
test -f .release/Hyprspace.app/Contents/Resources/Assets.car
test -f .release/Hyprspace.app/Contents/Resources/AppIcon.icns
test -f .release/Hyprspace-v${build_version}.zip

iconset_parent_dir="$(mktemp -d)"
iconset_dir="$iconset_parent_dir/AppIcon.iconset"
trap 'rm -rf "$iconset_parent_dir"' EXIT

echo "[step] checking xcodebuild asset catalog warnings"
if grep -q 'AppIcon.appiconset/(null)\[2d\]\[icon.png\]' .release/xcodebuild.log; then
    echo "[error] unexpected stray icon.png warning in xcodebuild log"
    grep 'AppIcon.appiconset/(null)\[2d\]\[icon.png\]' .release/xcodebuild.log
    exit 1
fi

echo "[step] validating packaged public docs and license surfaces"
python3 "$root_dir/scripts/internal/validate-public-release-surface.py" --phase zip --zip "$checkout_dir/.release/Hyprspace-v${build_version}.zip"

echo "[step] checking built AppIcon.icns content"
/usr/bin/xcrun iconutil -c iconset .release/Hyprspace.app/Contents/Resources/AppIcon.icns -o "$iconset_dir"
for pair in \
    "icon_16x16@2x.png:artifacts/gfx/icons/IconComposer-iOS-Default-16x16@2x.png" \
    "icon_128x128.png:artifacts/gfx/icons/IconComposer-iOS-Default-128x128@1x.png" \
    "icon_128x128@2x.png:artifacts/gfx/icons/IconComposer-iOS-Default-128x128@2x.png"; do
    built_name="${pair%%:*}"
    source_path="$root_dir/${pair#*:}"
    built_path="$iconset_dir/$built_name"
    echo "[info] comparing $built_path to $source_path"
    cmp "$built_path" "$source_path"
done

echo "[step] checking production version output"
output="$(.release/hyprspace --version 2>&1)"
printf '%s\n' "$output"
test "$output" = "Hyprspace v${build_version}"

echo "[step] checking packaged init wrapper dispatch"
output="$(HYPRSPACE_INIT_TEST_MODE=runtime .release/hyprspace init 2>&1)"
printf '%s\n' "$output"
grep -q '"runtime_root":' <<<"$output"
grep -q '"apply_script_exists": true' <<<"$output"

echo "[ok] hyprspace release build test passed"
