#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../.."
source ./product.conf
source ./scripts/release/release-lib.sh
source ./scripts/verify/repo-state-table.sh

NEW_VERSION=""

while test $# -gt 0; do
    case "$1" in
    --*)
        echo "error: unknown option: $1" >&2
        exit 1
        ;;
    *)
        NEW_VERSION="$1"
        shift
        ;;
    esac
done

if [ -z "$NEW_VERSION" ]; then
    echo "error: version argument is required" >&2
    echo "usage: $0 <semver-version>" >&2
    echo "example: $0 0.1.3" >&2
    exit 1
fi

bash ./scripts/release/pre-release-checks.sh "$NEW_VERSION"

mkdir -p ./log/release
publish_log_file="./log/release/$(date -u +%Y%m%dT%H%M%SZ)-publish-hyprspace-release.log"
exec > >(tee "$publish_log_file") 2>&1

BUILD_VERSION="$NEW_VERSION"
TAG="${HYPRSPACE_TAG_PREFIX}${BUILD_VERSION}"
ZIP_NAME="Hyprspace-v${BUILD_VERSION}.zip"
ZIP_PATH="AeroSpace/.release/${ZIP_NAME}"
ZIP_URL="https://github.com/${HYPRSPACE_RELEASES_REPO}/releases/download/${TAG}/${ZIP_NAME}"
TAP_DIR="../../homebrew-tap"
RELEASES_DIR="../hyprspace-releases"
RELEASE_NOTES_PATH="AeroSpace/.release/release-notes.md"
publish_exit_label="final"
public_zip=""
publish_success_line=""

publish_release_on_exit() {
    local exit_code=$?
    print_repo_state_table "$publish_exit_label" \
        source "." \
        tap "$TAP_DIR" \
        releases "$RELEASES_DIR"
    if [ -n "$public_zip" ] && [ -f "$public_zip" ]; then
        rm -f "$public_zip"
    fi
    if [ "$exit_code" -eq 0 ] && [ -n "$publish_success_line" ]; then
        echo "$publish_success_line"
    fi
    return "$exit_code"
}

trap publish_release_on_exit EXIT

print_release_boundary() {
    local label="$1"
    local note="${2:-}"
    if [ -n "$note" ]; then
        echo "[$label] $note"
    fi
    echo "[$label] .release listing"
    if [ -d "AeroSpace/.release" ]; then
        ls -l "AeroSpace/.release"
    else
        echo "[info] missing AeroSpace/.release"
    fi
    echo "[$label] zip boundary"
    if [ -f "$ZIP_PATH" ]; then
        stat -f '%Sm %z %N' -t '%Y-%m-%d %H:%M:%S' "$ZIP_PATH"
        shasum -a 256 "$ZIP_PATH"
    else
        echo "[info] missing $ZIP_PATH"
    fi
}

capture_zip_boundary() {
    if [ -f "$ZIP_PATH" ]; then
        stat -f '%m %z' "$ZIP_PATH"
        shasum -a 256 "$ZIP_PATH"
    else
        echo "missing"
    fi
}

sync_live_release_patch_truth() {
    local patch_name="hyprspace/install-surface-identity.patch"
    local patch_path="patches/$patch_name"
    local before_hash after_hash

    if ! git -C "AeroSpace" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "[info] AeroSpace checkout missing; skipping live release-patch sync"
        return 0
    fi

    before_hash="$(shasum -a 256 "$patch_path" 2>/dev/null || echo missing)"
    ./scripts/patch/regenerate-patch.sh "$patch_name" --add-file script/internal/build-release.sh
    after_hash="$(shasum -a 256 "$patch_path" 2>/dev/null || echo missing)"

    if [ "$before_hash" != "$after_hash" ]; then
        git --no-pager diff -- "$patch_path" >&2 || true
        echo "[clue] live AeroSpace release-surface edits existed only in the ephemeral checkout, not in patch truth." >&2
        echo "[clue] if publish continued, refresh-workspace would wipe those edits before the build and you would ship stale release behavior." >&2
        echo "[clue] commit $patch_path first, then rerun the release flow." >&2
        die "live AeroSpace release-surface edits changed patch truth; commit $patch_path before rerunning the release flow"
    fi
}

commit_version_file() {
    git add version.txt CHANGELOG.md
    git commit -m "Release $TAG"
}

push_release_commit() {
    git push origin main
}

# GitHub's CDN can serve transient 404s for a freshly created release
# asset for tens of seconds after `gh release create` returns. Without
# retries, a CDN propagation race here would leave us with a published
# release that we never validated. Retry with backoff so transient
# 404s do not abort the publish flow.
download_public_zip() {
    local destination="$1"
    local delays="2 5 10 20 30"
    local attempt=0
    local total_attempts=5
    local curl_exit=0
    local delay
    for delay in $delays; do
        attempt=$((attempt + 1))
        if curl -fsSL "$ZIP_URL" -o "$destination"; then
            return 0
        fi
        curl_exit=$?
        if [ "$attempt" -lt "$total_attempts" ]; then
            echo "[warn] download attempt $attempt failed (curl exit $curl_exit); retrying in ${delay}s..." >&2
            sleep "$delay"
        fi
    done
    return "$curl_exit"
}

verify_release_body() {
    local body
    body="$(gh release view "$TAG" --repo "$HYPRSPACE_RELEASES_REPO" --json body -q .body)"
    test -n "$body" || die "GitHub release body is empty for $TAG"
}

step "preflight"
require_cmd curl

if [[ -z "${SKIP_REFRESH_WORKSPACE:-}" ]]; then
    step "refreshing patched AeroSpace checkout from patch truth"
    ./scripts/patch/refresh-workspace.sh

    step "syncing live release patch truth"
    sync_live_release_patch_truth
else
    step "skipping workspace refresh (SKIP_REFRESH_WORKSPACE set by upgrade-upstream)"
fi

step "regenerating patch docs"
patches_doc_before_hash="$(shasum -a 256 docs/patches.md 2>/dev/null || echo missing)"
python3 ./scripts/internal/generate-patches-doc.py
patches_doc_after_hash="$(shasum -a 256 docs/patches.md 2>/dev/null || echo missing)"
if [ "$patches_doc_before_hash" != "$patches_doc_after_hash" ]; then
    git --no-pager diff -- docs/patches.md >&2 || true
    die "docs/patches.md changed after regeneration; commit the generated file before releasing"
fi

step "validating patch stack"
PATCH_BIN="$(command -v gpatch)" bash scripts/patch/validate-patches.sh

step "committing release version"
echo "$NEW_VERSION" >version.txt
commit_version_file

step "checking install surface"
bash tests/test-hyprspace-install-surface.sh

step "building and validating release artifact"
before_zip_boundary="$(capture_zip_boundary)"
print_release_boundary before-build "pre-rebuild snapshot only; existing .release contents may be stale until the build step below replaces them"
RUN_INTEGRATION_TESTS=1 /bin/bash tests/test-hyprspace-release-build.sh --build-version "$BUILD_VERSION"
print_release_boundary after-build "fresh post-build artifact boundary"
test -f "$ZIP_PATH" || die "release build did not produce expected artifact $ZIP_PATH"
after_zip_boundary="$(capture_zip_boundary)"
if [ "$before_zip_boundary" = "$after_zip_boundary" ]; then
    die "release build step did not refresh $ZIP_PATH"
fi

step "rendering local owned public surfaces"
python3 ./scripts/internal/validate-public-release-surface.py --phase local-owned-sync
test -s "$RELEASE_NOTES_PATH" || die "rendered release notes are empty"

step "running packaged local install smoke"
RUN_INTEGRATION_TESTS=1 /bin/bash tests/test-hyprspace-local-install.sh

step "syncing and validating local public surfaces"
python3 ./scripts/internal/validate-public-release-surface.py --phase local-sync
bash tests/test-hyprspace-public-surface-docs.sh

step "syncing public releases repo docs"
sync_repo_if_needed "$RELEASES_DIR" "releases" "docs: sync public release surface" README.md LEGAL.md LICENSE

step "pushing release commit"
push_release_commit

step "tagging source repo"
git tag -a "$TAG" -m "$TAG"
if ! git push origin "$TAG"; then
    die "failed to push tag $TAG to origin; source commit was already pushed. Inspect local/remote tags before retrying: git tag -l '$TAG' && git ls-remote --tags origin '$TAG'"
fi

step "publishing GitHub release"
if ! gh release create "$TAG" "$ZIP_PATH" \
    --repo "$HYPRSPACE_RELEASES_REPO" \
    --title "$TAG" \
    --notes-file "$RELEASE_NOTES_PATH"; then
    die "failed to publish GitHub release $TAG; source commit and tag were already pushed. Inspect release state before retrying: gh release view '$TAG' --repo '$HYPRSPACE_RELEASES_REPO'"
fi

step "verifying release notes body"
verify_release_body

step "generating tap cask from published asset"
(
    cd AeroSpace
    ./script/build-brew-cask.sh \
        --cask-name hyprspace \
        --zip-uri "$ZIP_URL" \
        --build-version "$BUILD_VERSION"
)

step "updating public tap repo"
cp artifacts/docs/homebrew-hyprspace-README.md "$TAP_DIR/README.md"
cp AeroSpace/.release/hyprspace.rb "$TAP_DIR/Casks/hyprspace.rb"
sync_repo_if_needed "$TAP_DIR" "tap" "hyprspace: ${TAG}" README.md Casks/hyprspace.rb

step "syncing legacy tap mirror (homebrew-hyprspace)"
LEGACY_TAP_REMOTE="git@github.com:PeachlifeAB/homebrew-hyprspace.git"
if git -C "$TAP_DIR" remote get-url legacy >/dev/null 2>&1; then
    git -C "$TAP_DIR" remote set-url legacy "$LEGACY_TAP_REMOTE"
else
    git -C "$TAP_DIR" remote add legacy "$LEGACY_TAP_REMOTE"
fi
if ! git -C "$TAP_DIR" push legacy main; then
    echo "[warn] legacy tap mirror push failed (non-fatal); continuing" >&2
fi
print_repo_state_table post-public-sync \
    source "." \
    tap "$TAP_DIR" \
    releases "$RELEASES_DIR"

public_zip="$(mktemp -t hyprspace-public-release.XXXXXX.zip)"

step "downloading public zip for validation"
download_public_zip "$public_zip"

step "validating public release surfaces"
python3 ./scripts/internal/validate-public-release-surface.py --phase public --zip "$public_zip"

step "running public install smoke"
RUN_PUBLIC_RELEASE_SMOKE=1 /bin/bash tests/test-hyprspace-public-release-smoke.sh

publish_success_line="PUBLISH SUCCESS: ${TAG}"
