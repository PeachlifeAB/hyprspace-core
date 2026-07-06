#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root_dir"

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "error: missing required command: $1"
}

hash_file() {
    local path="$1"
    if [ -f "$path" ]; then
        shasum -a 256 "$path"
    else
        echo "missing  $path"
    fi
}

verify_generated_patch() {
    local patch_name="$1"
    shift
    local patch_path="patches/$patch_name"
    local before_hash after_hash

    test -f "$patch_path" || die "error: generated patch target missing: $patch_path"

    before_hash="$(hash_file "$patch_path")"
    ./scripts/patch/regenerate-patch.sh "$patch_name" "$@"
    after_hash="$(hash_file "$patch_path")"

    if [ "$before_hash" != "$after_hash" ]; then
        echo "[err] generated patch drift: $patch_path" >&2
        git --no-pager diff -- "$patch_path" >&2 || true
        return 1
    fi

    echo "[ok] generated patch current: $patch_path"
}

require_cmd git
require_cmd shasum
require_cmd gpatch

if [[ "${VERIFY_GENERATED_PATCHES_SKIP_REFRESH:-0}" != "1" ]]; then
    echo "[step] refreshing patched AeroSpace checkout from patch truth"
    ./scripts/patch/refresh-workspace.sh
fi

failures=0

echo "[step] verifying generated patch truth"
verify_generated_patch "hyprspace/install-surface-identity.patch" --add-file script/internal/build-release.sh || failures=$((failures + 1))

if [ "$failures" -gt 0 ]; then
    echo "[clue] live AeroSpace generated edits differ from patch truth." >&2
    echo "[clue] commit the changed patch file(s), then rerun this verifier." >&2
    die "generated patch truth drift detected in $failures patch(es)"
fi
