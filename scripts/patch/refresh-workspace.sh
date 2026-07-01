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

# Scratch file to capture 3-way merge stderr for the failure report.
THREE_WAY_ERR="$(mktemp -t hyprspace-3way.XXXXXX)"
trap 'rm -f "$THREE_WAY_ERR"' EXIT

apply_patch_entry() {
    # Apply one series patch onto the current AeroSpace/ worktree.
    #   return 0 = applied (clean zero-fuzz OR auto-resolved via 3-way merge)
    #   return 1 = genuine conflict that needs a manual rebase
    local pf="$1"

    # Tier 1 — strict, zero-fuzz GNU patch. Dry-run first so a partially
    # matching patch never leaves the worktree half-applied (which would
    # corrupt the Tier 2 merge base).
    if "$PATCH_BIN" -p1 --ignore-whitespace --forward --dry-run \
        -i "../patches/$pf" -d . >/dev/null 2>&1; then
        "$PATCH_BIN" -p1 --ignore-whitespace --forward \
            -i "../patches/$pf" -d . --no-backup-if-mismatch >/dev/null
        return 0
    fi

    # Tier 2 — automatic 3-way merge (Helium/Chromium-roller style). Uses the
    # blob identities the patch records to reconstruct the ancestor and merge
    # our patched tree against the patch intent. This absorbs upstream drift
    # (line offsets, adjacent edits) automatically; only a genuine semantic
    # conflict, or a patch without recoverable blob identity, falls through.
    git add -A >/dev/null 2>&1 || true
    if git apply --3way --whitespace=nowarn "../patches/$pf" 2>"$THREE_WAY_ERR"; then
        git add -A >/dev/null 2>&1 || true
        echo "   ⚙ auto-resolved via 3-way merge (upstream drift absorbed)"
        return 0
    fi
    return 1
}

while IFS= read -r patch_file; do
    # Skip empty lines or comments
    [[ -z "$patch_file" || "$patch_file" == \#* ]] && continue

    # Trim whitespace
    patch_file=$(echo "$patch_file" | xargs)

    echo "-> Applying $patch_file"
    if apply_patch_entry "$patch_file"; then
        continue
    fi

    # --- Genuine conflict: neither zero-fuzz nor 3-way could finish it. ---
    conflict_files="$(grep -rl '^<<<<<<< ' . 2>/dev/null | sed 's|^\./|  AeroSpace/|' | sort)"
    rej_files="$(find . -name '*.rej' 2>/dev/null | sed 's|^\./|  AeroSpace/|' | sort)"
    three_way_msg="$(sed 's/^/    /' "$THREE_WAY_ERR" 2>/dev/null || true)"
    base_version="$(cat "$ROOT_DIR/aerospace_version.txt" 2>/dev/null || echo '?')"
    base_rev="$(cat "$ROOT_DIR/revision.txt" 2>/dev/null || echo '?')"
    patch_stem="$(basename "$patch_file" .patch)"
    cat >&2 <<EOF

════════════════════════════════════════════════════════════════
❌ PATCH CONFLICT — MANUAL REBASE REQUIRED
════════════════════════════════════════════════════════════════
Patch:  patches/$patch_file
Base:   AeroSpace v${base_version} (rev ${base_rev})

The automation already tried, in order:
  1. strict zero-fuzz apply (GNU patch)  -> did not apply
  2. automatic 3-way merge               -> could not resolve
${three_way_msg:+$three_way_msg}

Upstream rewrote the code this patch targets, so no tool can safely
finish it — the patch intent must be re-expressed against the new code.

Files needing hand resolution:
${conflict_files:-${rej_files:-  (inspect with: git -C AeroSpace status)}}

HOW TO FIX (Scenario A — .claude/skills/patch-based-development/SKILL.md):
  AeroSpace/ is pinned at the NEW base v${base_version} with every patch
  up to this one applied, so you are already positioned to rebase.

  1. cd AeroSpace
  2. Resolve the conflict markers (<<<<<<< / >>>>>>>) or .rej hunks so the
     file reflects this patch's intent on the new upstream code.
  3. Re-export just this patch (Scenario A: temp-commit the baseline, edit,
     then 'git format-patch' over patches/$patch_file).
  4. Commit it from the repo root:
       git add patches/$patch_file
       git commit -m "patch: rebase ${patch_stem} onto AeroSpace v${base_version}"
  5. Resume — re-applies the whole stack, auto-resolving what it can:
       mise run release:upgrade-upstream    # or: mise run patch:refresh-workspace

⚠  Patches after this one were NOT applied. Fixing this may reveal the next
   conflict — an upstream rebase is iterative, one patch at a time.
════════════════════════════════════════════════════════════════
EOF
    exit 1
done <"$ROOT_DIR/patches/series"

echo "======================================================"
echo "✅ Workspace successfully refreshed and patched!"
echo "======================================================"
