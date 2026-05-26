#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/scripts/internal/init-human-log.sh"
init_human_log "$ROOT_DIR" patch refresh-workspace
source "$ROOT_DIR/scripts/verify/repo-state-table.sh"
source "$ROOT_DIR/product.conf"
REPO_URL="$AEROSPACE_UPSTREAM_URL"

resolve_patch_bin() {
    local candidate
    if [[ -n "${PATCH_BIN:-}" ]]; then
        candidate="$PATCH_BIN"
        if [[ ! -x "$candidate" ]]; then
            echo "❌ ERROR: PATCH_BIN=$candidate is not executable or does not exist." >&2
            exit 1
        fi
    elif command -v gpatch >/dev/null 2>&1; then
        candidate="$(command -v gpatch)"
    else
        echo "❌ ERROR: GNU patch is required as 'gpatch', but it was not found in PATH." >&2
        echo "   Install it with: brew install gpatch" >&2
        exit 1
    fi

    if [[ "$(basename "$candidate")" != "gpatch" ]]; then
        echo "❌ ERROR: PATCH_BIN must point to GNU patch installed as 'gpatch'." >&2
        echo "   Received: $candidate" >&2
        echo "   Install it with: brew install gpatch" >&2
        exit 1
    fi

    if ! "$candidate" --version 2>&1 | grep -qi "GNU patch"; then
        echo "❌ ERROR: $candidate does not appear to be GNU patch." >&2
        echo "   Install GNU patch: brew install gpatch" >&2
        exit 1
    fi

    echo "$candidate"
}

cd "$ROOT_DIR"

print_default_repo_state_table "refresh-workspace-preflight"
print_patch_input_state "refresh-workspace-preflight"

PATCH_BIN="$(resolve_patch_bin)"
echo "-> Using GNU patch: $PATCH_BIN ($("$PATCH_BIN" --version 2>&1 | head -1))"

if [ -d "AeroSpace" ]; then
    echo "-> AeroSpace/ directory exists. Fetching latest from origin..."
    cd AeroSpace
    if ! git fetch origin --tags; then
        echo "❌ ERROR: Failed to fetch from AeroSpace origin remote." >&2
        echo "   Check network connectivity and that origin URL is reachable." >&2
        exit 1
    fi
    # Abort any in-progress git rebase or am just in case
    git am --abort 2>/dev/null || true
    git rebase --abort 2>/dev/null || true
else
    echo "-> Cloning AeroSpace from $REPO_URL..."
    git clone "$REPO_URL" AeroSpace
    cd AeroSpace
fi

# Pin to the version recorded in aerospace_version.txt
PINNED_VERSION="$(read_aerospace_version)"
LATEST_TAG="v${PINNED_VERSION}"
if ! git rev-parse --verify "$LATEST_TAG" >/dev/null 2>&1; then
    echo "❌ ERROR: Tag $LATEST_TAG not found in AeroSpace repo."
    echo "   Run: git -C AeroSpace fetch --tags"
    echo "   Or update aerospace_version.txt to match an available tag."
    exit 1
fi
echo "======================================================"
echo "🔄 Refreshing AeroSpace workspace to $LATEST_TAG"
echo "======================================================"
git checkout main >/dev/null 2>&1 || true
# AeroSpace/ is ephemeral — patches/ is the source of truth. Any local
# edits here are intentionally discarded; export them as patches first.
git reset --hard "$LATEST_TAG"
git clean -fd

# Record version files from the tag we just reset to
AEROSPACE_VERSION="${LATEST_TAG#v}"
echo "$AEROSPACE_VERSION" >"$ROOT_DIR/aerospace_version.txt"
echo "-> aerospace_version.txt updated to $AEROSPACE_VERSION"
git rev-parse --short HEAD >"$ROOT_DIR/revision.txt"
echo "-> revision.txt updated to $(cat "$ROOT_DIR/revision.txt")"

echo "======================================================"
echo "🩹 Applying patches from patches/series..."
echo "======================================================"

while IFS= read -r patch_file; do
    # Skip empty lines or comments
    [[ -z "$patch_file" || "$patch_file" == \#* ]] && continue

    # Trim whitespace
    patch_file=$(echo "$patch_file" | xargs)

    echo "-> Applying $patch_file"
    if ! "$PATCH_BIN" -p1 --ignore-whitespace --forward -i "../patches/$patch_file" -d . --no-backup-if-mismatch; then
        echo "❌ ERROR: Failed to apply $patch_file!"
        echo "The tree has been left in a dirty state inside AeroSpace/"
        exit 1
    fi
done <"$ROOT_DIR/patches/series"

echo "======================================================"
echo "✅ Workspace successfully refreshed and patched!"
echo "======================================================"
