#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT_DIR/scripts/internal/init-human-log.sh"
init_human_log "$ROOT_DIR" patch validate-patches

LINT_ONLY=0

case "${1-}" in
--help | -h)
    cat <<'EOF'
Usage: bash scripts/patch/validate-patches.sh [--help]

Validate the full patches/series stack against a temporary pinned
AeroSpace checkout. The live AeroSpace/ checkout is never modified.

Steps performed:
  1. Require GNU patch installed as `gpatch` (or PATCH_BIN pointing to `gpatch`).
  2. Lint every in-series patch file before cloning: optional `# Summary: ...`, then plain `diff --git ...`, with no mailbox markers.
  3. Clone AeroSpace into a temp directory and reset to the pinned tag.
  4. For each patch listed in patches/series:
       a. dry-run with --fuzz=0 (must pass)
       b. apply for real with --fuzz=0 so later patches see cumulative state
  5. Report success with patch count, or exit 1 naming the failing patch.

Prerequisites:
  - GNU patch must be available (macOS: brew install gpatch).
  - Internet access is required on the first run to clone AeroSpace.

Options:
  --help, -h    Show this help text and exit.
  --lint-only   Run patch-format lint only and exit.

Examples:
  bash scripts/patch/validate-patches.sh
  PATCH_BIN=/opt/homebrew/bin/gpatch bash scripts/patch/validate-patches.sh
EOF
    exit 0
    ;;
--lint-only)
    LINT_ONLY=1
    ;;
"") ;;
*)
    echo "❌ ERROR: Unknown option: ${1}" >&2
    echo "   Use --help for usage." >&2
    exit 1
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCHES_DIR="$ROOT_DIR/patches"
SERIES_FILE="$PATCHES_DIR/series"
AEROSPACE_VERSION_FILE="$ROOT_DIR/aerospace_version.txt"
REPO_URL="https://github.com/nikitabobko/AeroSpace.git"

VALIDATE_TMP_DIR=""
cleanup() {
    if [[ -n "$VALIDATE_TMP_DIR" && -d "$VALIDATE_TMP_DIR" ]]; then
        rm -rf "$VALIDATE_TMP_DIR"
    fi
}
trap cleanup EXIT

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

    local candidate_name
    candidate_name="$(basename "$candidate")"
    if [[ "$candidate_name" != "gpatch" ]]; then
        echo "❌ ERROR: PATCH_BIN must point to GNU patch installed as 'gpatch'." >&2
        echo "   Received: $candidate" >&2
        echo "   Install it with: brew install gpatch" >&2
        exit 1
    fi

    local version_output
    version_output="$("$candidate" --version 2>&1 || true)"
    if ! echo "$version_output" | grep -qi "GNU patch"; then
        echo "❌ ERROR: $candidate does not appear to be GNU patch." >&2
        echo "   Version output: $version_output" >&2
        echo "   Install GNU patch: brew install gpatch" >&2
        exit 1
    fi

    echo "$candidate"
}

parse_series() {
    local series_file="$1"
    while IFS= read -r raw_line; do
        local line="${raw_line%%#*}"
        line="$(echo "$line" | xargs 2>/dev/null || true)"
        [[ -z "$line" ]] && continue
        echo "$line"
    done <"$series_file"
}

lint_patch_format() {
    local patch_file="$1"
    local bad_markers
    bad_markers="$(LC_ALL=C grep -nE '^(From [0-9a-f]{40} |From: |Date: |Subject: |---$|-- $|[0-9]+\.[0-9]+(\.[0-9]+)? \(Apple Git-)' "$patch_file" || true)"
    if [[ -n "$bad_markers" ]]; then
        echo "❌ ERROR: mailbox-format markers found in patch: $patch_file" >&2
        echo "$bad_markers" >&2
        echo "   Run: bash scripts/patch/normalize-series-patches.sh" >&2
        exit 1
    fi

    local first_payload_line
    first_payload_line="$(awk '
        /^# Summary:/ { next }
        /^[[:space:]]*$/ { next }
        { print; exit }
    ' "$patch_file")"

    if [[ "$first_payload_line" != diff\ --git\ * ]]; then
        echo "❌ ERROR: patch must start with 'diff --git' after optional summary lines: $patch_file" >&2
        echo "   First payload line: ${first_payload_line:-<empty>}" >&2
        echo "   Run: bash scripts/patch/normalize-series-patches.sh" >&2
        exit 1
    fi
}

if [[ ! -f "$AEROSPACE_VERSION_FILE" ]]; then
    echo "❌ ERROR: aerospace_version.txt not found at $AEROSPACE_VERSION_FILE" >&2
    exit 1
fi

if [[ ! -f "$SERIES_FILE" ]]; then
    echo "❌ ERROR: patches/series not found at $SERIES_FILE" >&2
    exit 1
fi

PATCH_BIN="$(resolve_patch_bin)"
echo "-> Using GNU patch: $PATCH_BIN ($("$PATCH_BIN" --version 2>&1 | head -1))"

PINNED_VERSION="$(cat "$AEROSPACE_VERSION_FILE")"
LATEST_TAG="v${PINNED_VERSION}"
echo "-> Pinned AeroSpace version: $LATEST_TAG"

while IFS= read -r patch_entry; do
    patch_file="$PATCHES_DIR/$patch_entry"

    if [[ ! -f "$patch_file" ]]; then
        echo "❌ ERROR: Patch file not found: $patch_file" >&2
        echo "   (Referenced as '$patch_entry' in patches/series)" >&2
        exit 1
    fi

    if [[ ! -r "$patch_file" ]]; then
        echo "❌ ERROR: Patch file is not readable: $patch_file" >&2
        exit 1
    fi

    lint_patch_format "$patch_file"
done < <(parse_series "$SERIES_FILE")

if [[ "$LINT_ONLY" -eq 1 ]]; then
    echo "✅ Patch-format lint passed for all series patches."
    exit 0
fi

VALIDATE_TMP_DIR="$(mktemp -d)"
VALIDATE_CHECKOUT="$VALIDATE_TMP_DIR/AeroSpace"

echo "======================================================"
echo "📦 Preparing isolated temporary checkout at $VALIDATE_TMP_DIR"
echo "======================================================"

echo "-> Cloning AeroSpace from $REPO_URL..."
git clone "$REPO_URL" "$VALIDATE_CHECKOUT" --quiet

cd "$VALIDATE_CHECKOUT"

if ! git rev-parse --verify "$LATEST_TAG" >/dev/null 2>&1; then
    echo "❌ ERROR: Tag $LATEST_TAG not found in AeroSpace repo." >&2
    echo "   Update aerospace_version.txt to match an available tag." >&2
    exit 1
fi

git reset --hard "$LATEST_TAG" --quiet
git clean -fd --quiet >/dev/null

echo "-> Checkout pinned to $LATEST_TAG ($(git rev-parse --short HEAD))"

echo "======================================================"
echo "🔍 Validating patch stack from $SERIES_FILE"
echo "======================================================"

patch_count=0
validated_count=0

while IFS= read -r patch_entry; do
    patch_file="$PATCHES_DIR/$patch_entry"
    patch_count=$((patch_count + 1))

    echo "-> [$patch_count] Validating $patch_entry"

    patch_out_file="$(mktemp)"

    if ! "$PATCH_BIN" -p1 \
        --ignore-whitespace \
        --no-backup-if-mismatch \
        --dry-run \
        --fuzz=0 \
        -i "$patch_file" \
        -d "$VALIDATE_CHECKOUT" >"$patch_out_file" 2>&1; then
        echo "" >&2
        echo "❌ ERROR: Patch failed dry-run: $patch_entry" >&2
        echo "   Full patch path: $patch_file" >&2
        echo "   patch output:" >&2
        sed 's/^/   /' "$patch_out_file" >&2
        rm -f "$patch_out_file"
        exit 1
    fi

    if ! "$PATCH_BIN" -p1 \
        --ignore-whitespace \
        --no-backup-if-mismatch \
        --forward \
        --fuzz=0 \
        -i "$patch_file" \
        -d "$VALIDATE_CHECKOUT" >"$patch_out_file" 2>&1; then
        echo "" >&2
        echo "❌ ERROR: Patch failed real apply: $patch_entry" >&2
        echo "   Full patch path: $patch_file" >&2
        echo "   patch output:" >&2
        sed 's/^/   /' "$patch_out_file" >&2
        rm -f "$patch_out_file"
        exit 1
    fi

    rm -f "$patch_out_file"

    validated_count=$((validated_count + 1))
done < <(parse_series "$SERIES_FILE")

echo "======================================================"
echo "✅ All $validated_count patches validated successfully!"
echo "======================================================"
