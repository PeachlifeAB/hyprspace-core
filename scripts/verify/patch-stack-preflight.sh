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

require_tracked() {
    git ls-files --error-unmatch "$1" >/dev/null 2>&1 || die "error: required file must be tracked: $1"
}

require_cmd git
require_cmd python3
require_cmd rg
require_cmd gpatch

gpatch --version 2>&1 | head -1 | grep -qi 'GNU patch' || die "error: gpatch is not GNU patch"

require_tracked "scripts/patch/validate-patches.sh"
require_tracked "scripts/patch/verify-generated-patches.sh"
require_tracked "scripts/patch/normalize-series-patches.sh"
require_tracked "scripts/internal/generate-patches-doc.py"
require_tracked "patches/series"
require_tracked "docs/patches.md"

bash scripts/patch/validate-patches.sh --lint-only

python3 scripts/internal/generate-patches-doc.py

if ! git diff --quiet -- docs/patches.md; then
    git --no-pager diff -- docs/patches.md >&2 || true
    die "error: docs/patches.md is out of date"
fi
