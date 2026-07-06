#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root_dir"

source ./product.conf
source ./scripts/release/release-lib.sh
source ./scripts/verify/repo-state-table.sh

new_version="${1:-}"
tag="${HYPRSPACE_TAG_PREFIX}${new_version}"
tap_dir="../../homebrew-tap"
releases_dir="../hyprspace-releases"

assert_changelog_mentions_version() {
    test -f "CHANGELOG.md" || die "missing CHANGELOG.md"
    grep -Fq "$new_version" CHANGELOG.md || die "CHANGELOG.md must mention $new_version before publish"
}

assert_manifest_sources_exist() {
    local manifest="scripts/internal/public-release-surface-manifest.json"
    test -f "$manifest" || die "missing release surface manifest at $manifest"

    local failures=0
    local sources
    sources="$(jq -r '.entries[].source' "$manifest")"
    while IFS= read -r src; do
        [ -z "$src" ] && continue
        if [ ! -f "$src" ]; then
            echo "[error] manifest source missing: $src" >&2
            failures=$((failures + 1))
        fi
    done <<<"$sources"

    local assertion_paths
    assertion_paths="$(jq -r '.assertions[].local_path // empty' "$manifest")"
    while IFS= read -r apath; do
        [ -z "$apath" ] && continue
        # assertion paths may be generated during build; only check if the
        # parent directory exists (catches wrong directory prefixes)
        local parent
        parent="$(dirname "$apath")"
        if [ ! -d "$parent" ]; then
            echo "[error] manifest assertion parent dir missing: $parent (for $apath)" >&2
            failures=$((failures + 1))
        fi
    done <<<"$assertion_paths"

    if [ "$failures" -gt 0 ]; then
        die "manifest references $failures missing source file(s); fix paths in $manifest"
    fi
}

assert_patch_series_integrity() {
    local series_file="patches/series"
    test -f "$series_file" || die "missing $series_file"

    local failures=0
    while IFS= read -r entry; do
        entry="$(echo "$entry" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$entry" ] && continue
        local patch_path="patches/$entry"
        if [ ! -f "$patch_path" ]; then
            echo "[error] series entry references missing patch: $patch_path" >&2
            failures=$((failures + 1))
            continue
        fi
        if ! grep -q '^# Summary: ' "$patch_path"; then
            echo "[error] patch missing # Summary: metadata: $patch_path" >&2
            failures=$((failures + 1))
        fi
    done <"$series_file"

    if [ "$failures" -gt 0 ]; then
        die "patch series has $failures issue(s); fix before releasing"
    fi
}

assert_patches_doc_current() {
    local doc="docs/patches.md"
    test -f "$doc" || die "missing $doc"

    local before_hash after_hash
    before_hash="$(shasum -a 256 "$doc")"
    python3 ./scripts/internal/generate-patches-doc.py
    after_hash="$(shasum -a 256 "$doc")"

    if [ "$before_hash" != "$after_hash" ]; then
        git checkout -- "$doc" 2>/dev/null || true
        die "$doc is stale; run: python3 scripts/internal/generate-patches-doc.py && commit"
    fi
}

assert_brew_tap_reachable() {
    # Verify the Homebrew tap is installed and fetchable so the smoke test
    # won't fail late in the pipeline. Also checks that brew --repository
    # resolves, which catches untapped or renamed taps.
    require_cmd brew
    local brew_tap_dir
    brew_tap_dir="$(brew --repository peachlifeab/tap 2>/dev/null || true)"
    if [[ -z "$brew_tap_dir" || ! -d "$brew_tap_dir/.git" ]]; then
        die "Homebrew tap peachlifeab/tap is not installed; run: brew tap PeachlifeAB/tap"
    fi

    if ! git -C "$brew_tap_dir" fetch --quiet origin main 2>/dev/null; then
        die "Homebrew tap at $brew_tap_dir cannot fetch from origin; check remote URL"
    fi
}

assert_publish_version_available() {
    local prev_version lower

    if ! git fetch --tags origin >/dev/null 2>&1; then
        echo "[warn] failed to fetch tags from origin; remote-tag checks may be stale" >&2
    fi
    prev_version="$(git -c color.ui=never tag --list "${HYPRSPACE_TAG_PREFIX}*" --sort=-version:refname | head -1 | sed "s/^${HYPRSPACE_TAG_PREFIX}//")"
    if [ -n "$prev_version" ]; then
        lower="$(printf '%s\n%s' "$prev_version" "$new_version" | sort -V | head -1)"
        if [ "$lower" != "$prev_version" ] || [ "$prev_version" = "$new_version" ]; then
            die "version $new_version must be greater than previous tag $prev_version"
        fi
    fi

    if git rev-parse --verify -q "refs/tags/$tag" >/dev/null; then
        die "source repo already has local tag $tag; delete it or use a new version"
    fi

    if git ls-remote --exit-code --tags origin "$tag" >/dev/null 2>&1; then
        die "source repo already has remote tag $tag; delete it or use a new version"
    fi

    if git -C "$releases_dir" ls-remote --exit-code --tags origin "$tag" >/dev/null 2>&1; then
        die "releases repo already has remote tag $tag; delete it or use a new version"
    fi

    if gh release view "$tag" --repo "$HYPRSPACE_RELEASES_REPO" >/dev/null 2>&1; then
        die "GitHub release $tag already exists in $HYPRSPACE_RELEASES_REPO; delete it or use a new version"
    fi
}

if [ -z "$new_version" ]; then
    echo "error: version argument is required" >&2
    echo "usage: $0 <semver-version>" >&2
    echo "example: $0 0.1.3" >&2
    exit 1
fi

print_repo_state_table preflight \
    source "." \
    tap "$tap_dir" \
    releases "$releases_dir"

require_cmd git
require_cmd python3
require_cmd gpatch
require_git_repo "$tap_dir"
require_git_repo "$releases_dir"

require_cmd gh
require_cmd jq
assert_clean_repo "." "source"
assert_clean_repo "$tap_dir" "tap"
assert_clean_repo "$releases_dir" "releases"
ensure_repo_remote_ready "." "source"
ensure_repo_remote_ready "$tap_dir" "tap"
ensure_repo_remote_ready "$releases_dir" "releases"
assert_repo_push_safe "." "source" "${ALLOW_SOURCE_AHEAD_FOR_RELEASE:-0}"
assert_repo_push_safe "$tap_dir" "tap"
assert_repo_push_safe "$releases_dir" "releases"
assert_publish_version_available
assert_changelog_mentions_version
assert_manifest_sources_exist
assert_patch_series_integrity
assert_patches_doc_current
./scripts/patch/verify-generated-patches.sh
assert_brew_tap_reachable
