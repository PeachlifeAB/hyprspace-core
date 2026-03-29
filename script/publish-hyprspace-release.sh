#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./product.conf
source ./script/repo-state-table.sh

mkdir -p ./log/release
publish_log_file="./log/release/$(date -u +%Y%m%dT%H%M%SZ)-publish-hyprspace-release.log"
exec > >(tee "$publish_log_file") 2>&1

validate_only=0
while test $# -gt 0; do
    case "$1" in
    --validate-only)
        validate_only=1
        shift
        ;;
    *)
        echo "error: unknown option: $1" >&2
        exit 1
        ;;
    esac
done

BUILD_VERSION="$(tr -d '\r' <version.txt)"
TAG="${HYPRSPACE_TAG_PREFIX}${BUILD_VERSION}"
ZIP_NAME="Hyprspace-v${BUILD_VERSION}.zip"
ZIP_PATH="AeroSpace/.release/${ZIP_NAME}"
ZIP_URL="https://github.com/${HYPRSPACE_RELEASES_REPO}/releases/download/${TAG}/${ZIP_NAME}"
TAP_DIR="../homebrew-hyprspace"
RELEASES_DIR="../hyprspace-releases"
RELEASE_NOTES_PATH="AeroSpace/.release/release-notes.md"
publish_exit_label="final"
public_zip=""

publish_release_on_exit() {
    print_repo_state_table "$publish_exit_label" \
        source "." \
        tap "$TAP_DIR" \
        releases "$RELEASES_DIR"
    if [ -n "$public_zip" ] && [ -f "$public_zip" ]; then
        rm -f "$public_zip"
    fi
}

trap publish_release_on_exit EXIT

step() {
    echo "[step] $1"
}

die() {
    echo "[error] $1" >&2
    exit 1
}

print_release_boundary() {
    local label="$1"
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

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

require_git_repo() {
    local path="$1"
    test -d "$path" || die "missing required repo clone at $path"
    git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "path is not a git repo: $path"
}

assert_clean_source_repo() {
    if [ -n "$(git status --short)" ]; then
        git status --short >&2
        die "source repo has uncommitted changes; commit them before running the real publish path"
    fi
}

commit_if_needed() {
    local repo_path="$1"
    local commit_message="$2"
    shift 2
    git -C "$repo_path" add "$@"
    if git -C "$repo_path" diff --cached --quiet; then
        echo "[info] no commit needed in $repo_path"
        return 0
    fi
    git -C "$repo_path" commit -m "$commit_message"
    git -C "$repo_path" push
}

current_branch() {
    local repo_path="$1"
    git -C "$repo_path" symbolic-ref --quiet --short HEAD 2>/dev/null || echo main
}

has_upstream() {
    local repo_path="$1"
    git -C "$repo_path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1
}

ensure_repo_remote_ready() {
    local repo_path="$1"
    local label="$2"
    local branch
    branch="$(current_branch "$repo_path")"

    git -C "$repo_path" remote get-url origin >/dev/null 2>&1 || die "$label repo missing origin remote: $repo_path"

    if ! has_upstream "$repo_path"; then
        die "$label repo branch '$branch' has no upstream; push it first with: git -C $repo_path push -u origin $branch"
    fi

    git -C "$repo_path" fetch --quiet origin "$branch" >/dev/null 2>&1 || die "$label repo failed to fetch origin/$branch"
    git -C "$repo_path" rev-parse --verify "origin/$branch" >/dev/null 2>&1 || die "$label repo remote branch origin/$branch is missing"
}

sync_repo_if_needed() {
    local repo_path="$1"
    local label="$2"
    local commit_message="$3"
    shift 3
    local branch ahead_count

    commit_if_needed "$repo_path" "$commit_message" "$@"

    branch="$(current_branch "$repo_path")"
    if ! has_upstream "$repo_path"; then
        git -C "$repo_path" push -u origin "$branch"
        return 0
    fi

    git -C "$repo_path" fetch --quiet origin "$branch" >/dev/null 2>&1 || die "$label repo failed to fetch origin/$branch"
    ahead_count="$(git -C "$repo_path" rev-list --count "@{u}..HEAD")"
    if [ "$ahead_count" -gt 0 ]; then
        git -C "$repo_path" push
    else
        echo "[info] $label repo already synced to remote"
    fi
}

assert_clean_repo() {
    local repo_path="$1"
    if [ -n "$(git -C "$repo_path" status --short)" ]; then
        git -C "$repo_path" status --short >&2
        die "repo has uncommitted changes before publish: $repo_path"
    fi
}

download_public_zip() {
    local destination="$1"
    curl -fsSL "$ZIP_URL" -o "$destination"
}

verify_release_body() {
    local body
    body="$(gh release view "$TAG" --repo "$HYPRSPACE_RELEASES_REPO" --json body -q .body)"
    test -n "$body" || die "GitHub release body is empty for $TAG"
}

step "preflight"
require_cmd python3
require_cmd git
require_cmd curl
require_cmd gpatch
require_git_repo "$TAP_DIR"
require_git_repo "$RELEASES_DIR"
print_repo_state_table preflight \
    source "." \
    tap "$TAP_DIR" \
    releases "$RELEASES_DIR"
if [ "$validate_only" -eq 0 ]; then
    require_cmd gh
    assert_clean_source_repo
    assert_clean_repo "$TAP_DIR"
    assert_clean_repo "$RELEASES_DIR"
    ensure_repo_remote_ready "$TAP_DIR" "tap"
    ensure_repo_remote_ready "$RELEASES_DIR" "releases"
fi

step "regenerating patch docs"
patches_doc_before_hash="$(shasum -a 256 docs/dev/patches.md 2>/dev/null || echo missing)"
python3 ./script/generate-patches-doc.py
patches_doc_after_hash="$(shasum -a 256 docs/dev/patches.md 2>/dev/null || echo missing)"
if [ "$patches_doc_before_hash" != "$patches_doc_after_hash" ]; then
    git --no-pager diff -- docs/dev/patches.md >&2 || true
    die "docs/dev/patches.md changed after regeneration; commit the generated file before releasing"
fi

step "validating patch stack"
PATCH_BIN="$(command -v gpatch)" bash devutils/validate-patches.sh

step "refreshing patched AeroSpace checkout from patch truth"
./utils/refresh-workspace.sh

step "checking install surface"
bash tests/test-hyprspace-install-surface.sh

step "building and validating release artifact"
before_zip_boundary="$(capture_zip_boundary)"
print_release_boundary before-build
RUN_INTEGRATION_TESTS=1 /bin/bash tests/test-hyprspace-release-build.sh
print_release_boundary after-build
after_zip_boundary="$(capture_zip_boundary)"
if [ "$before_zip_boundary" = "$after_zip_boundary" ]; then
    die "release build step did not refresh $ZIP_PATH"
fi

step "rendering local owned public surfaces"
python3 ./script/validate-public-release-surface.py --phase local-owned-sync
test -s "$RELEASE_NOTES_PATH" || die "rendered release notes are empty"

step "validating local public surfaces"
python3 ./script/validate-public-release-surface.py --phase local

step "running packaged local install smoke"
RUN_INTEGRATION_TESTS=1 /bin/bash tests/test-hyprspace-local-install.sh

if [ "$validate_only" -eq 1 ]; then
    publish_exit_label="validate-only-final"
    echo "[ok] validate-only passed for ${TAG}"
    exit 0
fi

step "syncing and validating local public surfaces"
python3 ./script/validate-public-release-surface.py --phase local-sync
bash tests/test-hyprspace-public-surface-docs.sh

step "syncing public releases repo docs"
sync_repo_if_needed "$RELEASES_DIR" "releases" "docs: sync public release surface" README.md LEGAL.md LICENSE

step "tagging source repo"
git tag -a "$TAG" -m "$TAG"
git push origin "$TAG"

step "publishing GitHub release"
gh release create "$TAG" "$ZIP_PATH" \
    --repo "$HYPRSPACE_RELEASES_REPO" \
    --title "$TAG" \
    --notes-file "$RELEASE_NOTES_PATH"

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
cp docs/public/homebrew-hyprspace-README.md "$TAP_DIR/README.md"
cp AeroSpace/.release/hyprspace.rb "$TAP_DIR/Casks/hyprspace.rb"
sync_repo_if_needed "$TAP_DIR" "tap" "hyprspace: ${TAG}" README.md Casks/hyprspace.rb
print_repo_state_table post-public-sync \
    source "." \
    tap "$TAP_DIR" \
    releases "$RELEASES_DIR"

public_zip="$(mktemp -t hyprspace-public-release.XXXXXX.zip)"

step "downloading public zip for validation"
download_public_zip "$public_zip"

step "validating public release surfaces"
python3 ./script/validate-public-release-surface.py --phase public --zip "$public_zip"

step "running public install smoke"
RUN_PUBLIC_RELEASE_SMOKE=1 /bin/bash tests/test-hyprspace-public-release-smoke.sh

echo "[ok] release ${TAG} published"
