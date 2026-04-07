#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root_dir"

source ./product.conf
source ./scripts/verify/repo-state-table.sh

new_version="${1:-}"
tag="${HYPRSPACE_TAG_PREFIX}${new_version}"
tap_dir="../../brew"
releases_dir="../hyprspace-releases"

die() {
    printf '%s\n' "[error] $1" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

require_git_repo() {
    local path="$1"
    test -d "$path" || die "missing required repo clone at $path"
    git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "path is not a git repo: $path"
}

assert_changelog_mentions_version() {
    test -f "CHANGELOG.md" || die "missing CHANGELOG.md"
    grep -Fq "$new_version" CHANGELOG.md || die "CHANGELOG.md must mention $new_version before publish"
}

current_branch() {
    local repo_path="$1"
    git -C "$repo_path" symbolic-ref --quiet --short HEAD 2>/dev/null || echo main
}

has_upstream() {
    local repo_path="$1"
    git -C "$repo_path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1
}

assert_clean_repo() {
    local repo_path="$1"
    local label="$2"
    local dirty
    if [ "$repo_path" = "." ]; then
        dirty="$(git -c color.status=false -C "$repo_path" status --short | grep -v '^ M CHANGELOG\.md$' | grep -v '^M  CHANGELOG\.md$' || true)"
    else
        dirty="$(git -c color.status=false -C "$repo_path" status --short)"
    fi
    if [ -n "$dirty" ]; then
        git -C "$repo_path" status --short >&2
        die "$label repo has uncommitted changes; clean $repo_path before publish"
    fi
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

assert_repo_push_safe() {
    local repo_path="$1"
    local label="$2"
    local branch ahead behind counts
    branch="$(current_branch "$repo_path")"
    counts="$(git -c color.ui=never -C "$repo_path" rev-list --left-right --count "HEAD...@{u}")"
    ahead="${counts%%$'\t'*}"
    behind="${counts##*$'\t'}"

    if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
        die "$label repo branch '$branch' has diverged from origin/$branch (ahead $ahead, behind $behind); reconcile $repo_path before publish"
    fi

    if [ "$behind" -gt 0 ]; then
        die "$label repo branch '$branch' is behind origin/$branch by $behind commit(s); sync $repo_path before publish (for example: git -C $repo_path pull --ff-only)"
    fi

    if [ "$ahead" -gt 0 ]; then
        die "$label repo branch '$branch' is ahead of origin/$branch by $ahead commit(s); push or reset $repo_path before publish"
    fi
}

assert_publish_version_available() {
    local prev_version lower

    git fetch --tags origin >/dev/null 2>&1 || true
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
assert_clean_repo "." "source"
assert_clean_repo "$tap_dir" "tap"
assert_clean_repo "$releases_dir" "releases"
ensure_repo_remote_ready "." "source"
ensure_repo_remote_ready "$tap_dir" "tap"
ensure_repo_remote_ready "$releases_dir" "releases"
assert_repo_push_safe "." "source"
assert_repo_push_safe "$tap_dir" "tap"
assert_repo_push_safe "$releases_dir" "releases"
assert_publish_version_available
assert_changelog_mentions_version
