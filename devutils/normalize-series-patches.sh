#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
patches_dir="$root_dir/patches"
series_file="$patches_dir/series"

title_from_name() {
    local name="$1"
    name="${name##*/}"
    name="${name%.patch}"
    name="${name//-/ }"
    python3 - "$name" <<'PY'
import sys
print(sys.argv[1].title())
PY
}

parse_series() {
    while IFS= read -r raw; do
        line="${raw%%#*}"
        line="$(echo "$line" | xargs 2>/dev/null || true)"
        [[ -z "$line" ]] && continue
        echo "$line"
    done <"$series_file"
}

normalize_one() {
    local rel="$1"
    local f="$patches_dir/$rel"

    if [[ ! -f "$f" ]]; then
        echo "❌ ERROR: Patch file not found: $f" >&2
        exit 1
    fi

    local summary=""
    summary="$(LC_ALL=C awk '
        /^# Summary: / {
            sub(/^# Summary: /, "")
            print
            exit
        }
    ' "$f" || true)"

    if [[ -z "$summary" ]]; then
        summary="$(LC_ALL=C awk '
            /^Subject: / {
                sub(/^Subject: /, "")
                sub(/^\[PATCH\][[:space:]]*/, "")
                print
                exit
            }
        ' "$f" || true)"
    fi

    if [[ -z "$summary" ]]; then
        summary="$(title_from_name "$rel")"
    fi

    local tmp
    tmp="$(mktemp)"

    local diff_body
    diff_body="$(LC_ALL=C awk '
        BEGIN { in_diff = 0 }
        /^diff --git / { in_diff = 1 }
        /^-- $/ { exit }
        { if (in_diff) print }
    ' "$f")"

    if [[ -z "$diff_body" ]]; then
        rm -f "$tmp"
        echo "❌ ERROR: No diff body found in patch: $f" >&2
        exit 1
    fi

    {
        echo "# Summary: $summary"
        echo
        printf '%s\n' "$diff_body"
        echo
    } >"$tmp"

    mv "$tmp" "$f"
}

while IFS= read -r rel; do
    normalize_one "$rel"
done < <(parse_series)
