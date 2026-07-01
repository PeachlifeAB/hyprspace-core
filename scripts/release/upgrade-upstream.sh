#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"
source ./product.conf
source ./scripts/release/release-lib.sh
source ./scripts/verify/repo-state-table.sh

mkdir -p ./log/release
upgrade_log_file="./log/release/$(date -u +%Y%m%dT%H%M%SZ)-upgrade-upstream.log"
exec > >(tee "$upgrade_log_file") 2>&1

require_cmd git
require_cmd gh
require_cmd python3
require_cmd gpatch

# --- Detect latest AeroSpace tag ---

step "detecting latest AeroSpace tag from upstream"
NEW_AEROSPACE="$(latest_aerospace_tag)"
[ -n "$NEW_AEROSPACE" ] || die "could not detect latest AeroSpace tag"

OLD_AEROSPACE="$(read_aerospace_version)"

if [ "$NEW_AEROSPACE" = "$OLD_AEROSPACE" ]; then
    echo "[info] Already on AeroSpace v${OLD_AEROSPACE}, nothing to upgrade."
    exit 0
fi

echo "[info] New AeroSpace detected: v${OLD_AEROSPACE} → v${NEW_AEROSPACE}"

CURRENT_HYPRSPACE="$(cat version.txt)"
NEW_HYPRSPACE="$(next_hyprspace_version "$CURRENT_HYPRSPACE" "$OLD_AEROSPACE" "$NEW_AEROSPACE")"
BUMP_TYPE="$(aerospace_bump_type "$OLD_AEROSPACE" "$NEW_AEROSPACE")"
echo "[info] Bumping Hyprspace: v${CURRENT_HYPRSPACE} → v${NEW_HYPRSPACE} (${BUMP_TYPE} bump)"

# --- Source repo safety checks before mutating files ---

step "checking source repo safety"
assert_clean_repo "." "source" 0
ensure_repo_remote_ready "." "source"
assert_repo_push_safe "." "source"

# --- Bump aerospace_version.txt and refresh workspace ---

step "writing new AeroSpace version"
echo "$NEW_AEROSPACE" >aerospace_version.txt

step "refreshing patched workspace to v${NEW_AEROSPACE}"
if ! ./scripts/patch/refresh-workspace.sh; then
    # Deliberately do NOT roll back aerospace_version.txt / revision.txt.
    # refresh-workspace already pinned AeroSpace/ at the NEW base and printed
    # a "MANUAL REBASE REQUIRED" block above with the exact recovery steps.
    # Keeping the NEW base pinned leaves you positioned to rebase the failing
    # patch immediately, then re-run this command to resume. Nothing has been
    # committed or published — only the ephemeral checkout + version files
    # (both restorable with: git checkout -- aerospace_version.txt revision.txt).
    die "upstream patch stack did not apply on AeroSpace v${NEW_AEROSPACE}; follow the MANUAL REBASE block printed above, then re-run: mise run release:upgrade-upstream"
fi
# If any patch fails, refresh-workspace exits non-zero with clear output.
# Fix the conflict in AeroSpace/, re-export the owning patch (Scenario A in
# .claude/skills/patch-based-development/SKILL.md), commit the patch file,
# then rerun: mise run release:upgrade-upstream

# --- Regenerate derived artifacts ---

step "regenerating install-surface patch against new base"
./scripts/patch/regenerate-patch.sh hyprspace/install-surface-identity.patch \
    --add-file script/internal/build-release.sh

step "regenerating patch docs"
python3 ./scripts/internal/generate-patches-doc.py

# --- Update CHANGELOG.md ---

step "updating CHANGELOG.md"
CHANGELOG_BASE_LINE="> Current \`Hyprspace\` patches are based on AeroSpace v${NEW_AEROSPACE}"

# NOTE: the `sed -i ''` form below is BSD-sed (macOS) only. This script is
# macOS-only by design; do not "fix" these to GNU-sed style without also
# updating the platform contract.
if grep -qF '> Current `Hyprspace` patches are based on AeroSpace' CHANGELOG.md; then
    sed -i '' "s|^> Current \`Hyprspace\` patches are based on AeroSpace v.*|${CHANGELOG_BASE_LINE}|" CHANGELOG.md
else
    first_version_line=$(grep -n '^## \[' CHANGELOG.md | head -1 | cut -d: -f1)
    if [ -z "$first_version_line" ]; then
        die "could not find a '## [' version entry in CHANGELOG.md to insert before"
    fi
    sed -i '' "${first_version_line}i\
\
${CHANGELOG_BASE_LINE}\
" CHANGELOG.md
fi

# Verify the base-line edit actually landed.
grep -qF "${CHANGELOG_BASE_LINE}" CHANGELOG.md ||
    die "failed to update CHANGELOG base line"

if grep -qF "## [${NEW_HYPRSPACE}]" CHANGELOG.md; then
    echo "[info] CHANGELOG.md already has entry for ${NEW_HYPRSPACE}"
else
    first_version_line=$(grep -n '^## \[' CHANGELOG.md | head -1 | cut -d: -f1)
    if [ -z "$first_version_line" ]; then
        die "could not find a '## [' version entry in CHANGELOG.md to insert before"
    fi
    sed -i '' "${first_version_line}i\
\
## [${NEW_HYPRSPACE}] - $(date -u +%Y-%m-%d)\
\
### Changed\
- Upgraded AeroSpace base from v${OLD_AEROSPACE} to v${NEW_AEROSPACE}.\
" CHANGELOG.md
fi

# Verify the version-entry edit actually landed.
grep -qF "## [${NEW_HYPRSPACE}]" CHANGELOG.md ||
    die "failed to insert CHANGELOG entry for ${NEW_HYPRSPACE}"

# --- Commit the upstream bump ---

step "committing upstream bump"
# Stage the bump artifacts and commit only if there's something to commit.
# We deliberately do NOT use `commit_if_needed` here because that helper
# pushes immediately; the original semantics are to keep the upstream-bump
# commit local so the publish pipeline can push it atomically together
# with the release commit it adds on top.
git add \
    aerospace_version.txt \
    revision.txt \
    patches/hyprspace/install-surface-identity.patch \
    docs/patches.md \
    CHANGELOG.md
if git diff --cached --quiet; then
    echo "[info] no staged changes to commit for upstream bump"
else
    git commit -m "chore: upgrade AeroSpace base to v${NEW_AEROSPACE}"
fi

step "leaving upstream bump commit local for release push"
echo "[info] Publish will push this commit together with the release commit."

# --- Publish ---

echo ""
echo "[info] Continuing into publish pipeline for v${NEW_HYPRSPACE}..."
echo "[info] Upstream bump commit is local; publish pipeline will push it together with the release commit."
echo "[info] If publish fails, inspect the error-specific recovery message plus: git status --short && git log --oneline -3"
echo ""

exec env SKIP_REFRESH_WORKSPACE=1 ALLOW_SOURCE_AHEAD_FOR_RELEASE=1 bash ./scripts/release/publish-hyprspace-release.sh "$NEW_HYPRSPACE"
