#!/bin/bash
# Shared utilities for Hyprspace release scripts.
# Source this file; do not execute directly.
# Requires ROOT_DIR to be set by the caller.

die() {
    echo "[error] $1" >&2
    exit 1
}

step() {
    echo "[step] $1"
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

require_git_repo() {
    local path="$1"
    test -d "$path" || die "missing required repo clone at $path"
    git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "path is not a git repo: $path"
}

current_branch() {
    local repo_path="$1"
    git -C "$repo_path" symbolic-ref --quiet --short HEAD 2>/dev/null || echo main
}

has_upstream() {
    local repo_path="$1"
    git -C "$repo_path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1
}

commit_if_needed() {
    local repo_path="$1"
    local commit_message="$2"
    shift 2
    local branch
    git -C "$repo_path" add "$@"
    if git -C "$repo_path" diff --cached --quiet; then
        echo "[info] no commit needed in $repo_path"
        return 0
    fi
    git -C "$repo_path" commit -m "$commit_message"
    if has_upstream "$repo_path"; then
        git -C "$repo_path" push
    else
        branch="$(current_branch "$repo_path")"
        git -C "$repo_path" push -u origin "$branch"
    fi
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
    ahead_count="$(git -c color.ui=never -C "$repo_path" rev-list --count "@{u}..HEAD")"
    if [ "$ahead_count" -gt 0 ]; then
        git -C "$repo_path" push
    else
        echo "[info] $label repo already synced to remote"
    fi
}

assert_clean_repo() {
    local repo_path="$1"
    local label="$2"
    local allow_changelog_dirty="${3:-1}"
    local dirty
    if [ "$repo_path" = "." ] && [ "$allow_changelog_dirty" = "1" ]; then
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
    local allow_ahead="${3:-0}"
    local branch ahead behind counts
    branch="$(current_branch "$repo_path")"
    has_upstream "$repo_path" || die "$label repo branch '$branch' has no upstream; configure it before push-safety check"
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
        if [ "$allow_ahead" = "1" ]; then
            echo "[info] $label repo is ahead of origin/$branch by $ahead commit(s); release push will include them"
        else
            die "$label repo branch '$branch' is ahead of origin/$branch by $ahead commit(s); push or reset $repo_path before publish"
        fi
    fi
}

# latest_aerospace_tag
# Fetches the highest vX.Y.Z[-Suffix] tag from the AeroSpace upstream repo.
# Requires AEROSPACE_UPSTREAM_REPO to be set (from product.conf).
# Requires gh CLI.
latest_aerospace_tag() {
    local stdout_file stderr_file gh_status gh_stderr gh_stdout latest
    stdout_file="$(mktemp -t latest_aerospace_tag_stdout.XXXXXX)"
    stderr_file="$(mktemp -t latest_aerospace_tag_stderr.XXXXXX)"
    if gh api "repos/${AEROSPACE_UPSTREAM_REPO}/tags" --paginate \
        --jq '.[].name' >"$stdout_file" 2>"$stderr_file"; then
        gh_status=0
    else
        gh_status=$?
    fi
    gh_stdout="$(cat "$stdout_file")"
    gh_stderr="$(cat "$stderr_file")"
    rm -f "$stdout_file" "$stderr_file"
    if [ "$gh_status" -ne 0 ]; then
        if [ -n "$gh_stderr" ]; then
            echo "$gh_stderr" >&2
        fi
        die "could not fetch tags from ${AEROSPACE_UPSTREAM_REPO}: ${gh_stderr:-gh api exited with status $gh_status}"
    fi
    latest="$(printf '%s\n' "$gh_stdout" |
        grep -E '^v[0-9]+\.[0-9]+\.[0-9]+' |
        sort -V |
        tail -1 |
        sed 's/^v//' || true)"
    printf '%s\n' "$latest"
}

# next_hyprspace_version <current_hyprspace> <old_aerospace> <new_aerospace>
# Strips any suffix (e.g. "-Beta") before comparing upstream semver segments.
# Major or minor bump in AeroSpace → minor bump in Hyprspace. Otherwise → patch bump.
next_hyprspace_version() {
    local current="$1"
    local old_as="$2"
    local new_as="$3"

    current="${current%$'\n'}"
    old_as="${old_as%$'\n'}"
    new_as="${new_as%$'\n'}"

    if ! printf '%s' "$current" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
        die "next_hyprspace_version: invalid current version '$current'; expected MAJOR.MINOR.PATCH"
    fi
    if ! printf '%s' "$old_as" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+([.-].*)?$'; then
        die "next_hyprspace_version: invalid old aerospace version '$old_as'; expected MAJOR.MINOR.PATCH[-suffix]"
    fi
    if ! printf '%s' "$new_as" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+([.-].*)?$'; then
        die "next_hyprspace_version: invalid new aerospace version '$new_as'; expected MAJOR.MINOR.PATCH[-suffix]"
    fi

    local old_base new_base
    old_base="$(echo "$old_as" | sed 's/[^0-9.].*$//')"
    new_base="$(echo "$new_as" | sed 's/[^0-9.].*$//')"

    local old_major old_minor new_major new_minor
    old_major="$(echo "$old_base" | cut -d. -f1)"
    old_minor="$(echo "$old_base" | cut -d. -f2)"
    new_major="$(echo "$new_base" | cut -d. -f1)"
    new_minor="$(echo "$new_base" | cut -d. -f2)"

    local major minor patch
    major="$(echo "$current" | cut -d. -f1)"
    minor="$(echo "$current" | cut -d. -f2)"
    patch="$(echo "$current" | cut -d. -f3)"

    if [ "$new_major" -gt "$old_major" ] || [ "$new_minor" -gt "$old_minor" ]; then
        echo "${major}.$((minor + 1)).0"
    else
        echo "${major}.${minor}.$((patch + 1))"
    fi
}

aerospace_bump_type() {
    local old_as="$1"
    local new_as="$2"

    old_as="${old_as%$'\n'}"
    new_as="${new_as%$'\n'}"

    if ! printf '%s' "$old_as" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+([.-].*)?$'; then
        die "aerospace_bump_type: invalid old aerospace version '$old_as'; expected MAJOR.MINOR.PATCH[-suffix]"
    fi
    if ! printf '%s' "$new_as" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+([.-].*)?$'; then
        die "aerospace_bump_type: invalid new aerospace version '$new_as'; expected MAJOR.MINOR.PATCH[-suffix]"
    fi

    local old_base new_base
    old_base="$(echo "$old_as" | sed 's/[^0-9.].*$//')"
    new_base="$(echo "$new_as" | sed 's/[^0-9.].*$//')"

    local old_major old_minor new_major new_minor
    old_major="$(echo "$old_base" | cut -d. -f1)"
    old_minor="$(echo "$old_base" | cut -d. -f2)"
    new_major="$(echo "$new_base" | cut -d. -f1)"
    new_minor="$(echo "$new_base" | cut -d. -f2)"

    if [ "$new_major" -gt "$old_major" ] || [ "$new_minor" -gt "$old_minor" ]; then
        echo "minor"
    else
        echo "patch"
    fi
}
