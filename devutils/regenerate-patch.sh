#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${REGENERATE_PATCH_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PATCHES_DIR="$ROOT_DIR/patches"
SERIES_FILE="$PATCHES_DIR/series"
LIVE_TREE="$ROOT_DIR/AeroSpace"
AEROSPACE_VERSION_FILE="$ROOT_DIR/aerospace_version.txt"
ARTIFACT_EXCLUDES=(".git" ".build" ".swiftpm" ".xcode-build" ".release" ".deps" ".shell-completion" "log" "default.profraw")

TEMP_DIR=""
PATCH_BIN=""
TARGET_INPUT=""
TARGET_ENTRY=""
TARGET_INDEX=-1
TARGET_PATCH_FILE=""
TARGET_PATCH_NAME=""
PINNED_TAG=""
SUMMARY_PREFIX=""
declare -a SERIES_ENTRIES=()
declare -a BEFORE_PATCHES=()
declare -a AFTER_PATCHES=()
declare -a OWNED_FILES=()
declare -a ADD_FILES=()
declare -a ALLOWED_FILES=()

usage() {
    cat <<'EOF'
Usage: ./devutils/regenerate-patch.sh <patch-name> [--add-file <path> ...]

Regenerate exactly one existing in-series patch without mutating the live AeroSpace/ checkout.

The tool:
  - resolves the target patch from patches/series
  - reconstructs the correct pre-target base
  - rejects unrelated live AeroSpace/ edits by default
  - reverse-applies later patches in a temp tree
  - generates a repo-native plain diff patch
  - validates and replay-verifies before replacing the real patch file

Options:
  --add-file <path>   Allow one additional path to be owned by the regenerated patch.
  --help, -h          Show this help text and exit.
EOF
}

die() {
    printf '❌ ERROR: %s\n' "$*" >&2
    exit 1
}

info() {
    printf '%s\n' "-> $*"
}

print_path_block() {
    local label="$1"
    shift || true

    printf '%s\n' "$label" >&2
    if (($# == 0)); then
        printf '%s\n' '   - (none)' >&2
        return 0
    fi

    local path
    for path in "$@"; do
        printf '   - %s\n' "$path" >&2
    done
}

cleanup() {
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

resolve_patch_bin() {
    local candidate=""
    if [[ -n "${PATCH_BIN:-}" ]]; then
        candidate="$PATCH_BIN"
    elif command -v gpatch >/dev/null 2>&1; then
        candidate="$(command -v gpatch)"
    else
        die "GNU patch is required as 'gpatch'. Install it with: brew install gpatch"
    fi

    [[ -x "$candidate" ]] || die "Patch binary is not executable: $candidate"
    [[ "$(basename "$candidate")" == "gpatch" ]] || die "PATCH_BIN must point to GNU patch installed as 'gpatch'"

    local version_output
    version_output="$($candidate --version 2>&1 || true)"
    if [[ "$version_output" != *"GNU patch"* ]]; then
        die "$candidate does not appear to be GNU patch"
    fi

    PATCH_BIN="$candidate"
}

normalize_rel_path() {
    python3 - "$1" "$LIVE_TREE" <<'PY'
import os
import pathlib
import sys

raw = sys.argv[1]
live_tree = pathlib.Path(sys.argv[2]).resolve()
path = pathlib.Path(raw)
if path.is_absolute():
    try:
        rel = path.resolve().relative_to(live_tree)
    except Exception:
        print("", end="")
        raise SystemExit(2)
else:
    text = raw.replace('\\', '/')
    if text.startswith('./'):
        text = text[2:]
    if text.startswith('AeroSpace/'):
        text = text[len('AeroSpace/'):]
    rel = pathlib.PurePosixPath(text)

rel_text = rel.as_posix()
if rel_text in ('', '.'):
    print('', end='')
    raise SystemExit(2)
if rel_text.startswith('../') or '/..' in rel_text or rel_text == '..':
    print('', end='')
    raise SystemExit(2)
print(rel_text)
PY
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --help | -h)
            usage
            exit 0
            ;;
        --add-file)
            [[ $# -ge 2 ]] || die "--add-file requires a path argument"
            ADD_FILES+=("$2")
            shift 2
            ;;
        --*)
            die "Unknown option: $1"
            ;;
        *)
            if [[ -n "$TARGET_INPUT" ]]; then
                die "Only one target patch may be provided"
            fi
            TARGET_INPUT="$1"
            shift
            ;;
        esac
    done

    [[ -n "$TARGET_INPUT" ]] || die "Target patch name is required"
}

load_series() {
    [[ -f "$SERIES_FILE" ]] || die "patches/series not found at $SERIES_FILE"
    mapfile -t SERIES_ENTRIES < <(
        python3 - "$SERIES_FILE" <<'PY'
import pathlib
import sys

for raw in pathlib.Path(sys.argv[1]).read_text().splitlines():
    line = raw.split('#', 1)[0].strip()
    if line:
        print(line)
PY
    )
    [[ ${#SERIES_ENTRIES[@]} -gt 0 ]] || die "patches/series is empty"
}

resolve_target_patch() {
    local normalized_input
    normalized_input="$TARGET_INPUT"
    normalized_input="${normalized_input#$PATCHES_DIR/}"
    normalized_input="${normalized_input#patches/}"
    normalized_input="${normalized_input#./}"

    local bare_input="$normalized_input"
    bare_input="${bare_input%.patch}"
    local matches=()
    local idx=0
    local entry base bare
    for entry in "${SERIES_ENTRIES[@]}"; do
        base="$(basename "$entry")"
        bare="${base%.patch}"
        if [[ "$normalized_input" == "$entry" || "$normalized_input" == "$base" || "$bare_input" == "$bare" || "$normalized_input" == "$bare" ]]; then
            matches+=("$idx")
        fi
        idx=$((idx + 1))
    done

    if [[ ${#matches[@]} -eq 0 ]]; then
        die "Target patch '$TARGET_INPUT' is not present in patches/series"
    fi
    if [[ ${#matches[@]} -gt 1 ]]; then
        printf '❌ ERROR: Target patch reference is ambiguous: %s\n' "$TARGET_INPUT" >&2
        for idx in "${matches[@]}"; do
            printf '   - %s\n' "${SERIES_ENTRIES[$idx]}" >&2
        done
        exit 1
    fi

    TARGET_INDEX="${matches[0]}"
    TARGET_ENTRY="${SERIES_ENTRIES[$TARGET_INDEX]}"
    TARGET_PATCH_FILE="$PATCHES_DIR/$TARGET_ENTRY"
    TARGET_PATCH_NAME="$(basename "$TARGET_ENTRY")"
}

split_series() {
    local idx
    for idx in "${!SERIES_ENTRIES[@]}"; do
        if ((idx < TARGET_INDEX)); then
            BEFORE_PATCHES+=("${SERIES_ENTRIES[$idx]}")
        elif ((idx > TARGET_INDEX)); then
            AFTER_PATCHES+=("${SERIES_ENTRIES[$idx]}")
        fi
    done
}

extract_summary_prefix() {
    SUMMARY_PREFIX="$(
        python3 - "$TARGET_PATCH_FILE" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
marker = 'diff --git '
idx = text.find(marker)
print(text[:idx] if idx != -1 else text, end='')
PY
    )"
}

extract_owned_files() {
    mapfile -t OWNED_FILES < <(
        python3 - "$TARGET_PATCH_FILE" <<'PY'
import pathlib
import re
import sys

pattern = re.compile(r'^diff --git a/(.+?) b/(.+)$')
seen = set()
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    match = pattern.match(line)
    if not match:
        continue
    left, right = match.groups()
    candidates = []
    if left != '/dev/null':
        candidates.append(left)
    if right != '/dev/null' and right != left:
        candidates.append(right)
    for candidate in candidates:
        if candidate not in seen:
            seen.add(candidate)
            print(candidate)
PY
    )
    [[ ${#OWNED_FILES[@]} -gt 0 ]] || die "Could not derive owned files from $TARGET_ENTRY"
}

normalize_add_files() {
    local normalized=()
    local raw path
    for raw in "${ADD_FILES[@]}"; do
        if ! path="$(normalize_rel_path "$raw")"; then
            die "Invalid --add-file path: $raw"
        fi
        normalized+=("$path")
    done
    ADD_FILES=("${normalized[@]}")
}

add_unique_path() {
    local path="$1"
    local existing
    for existing in "${ALLOWED_FILES[@]:-}"; do
        [[ "$existing" == "$path" ]] && return 0
    done
    ALLOWED_FILES+=("$path")
}

build_allowed_files() {
    local path
    for path in "${OWNED_FILES[@]}"; do
        add_unique_path "$path"
    done
    for path in "${ADD_FILES[@]}"; do
        add_unique_path "$path"
    done
}

check_add_file_collisions() {
    local entry owned_path add_path
    declare -A owners=()
    for entry in "${SERIES_ENTRIES[@]:-}"; do
        [[ "$entry" == "$TARGET_ENTRY" ]] && continue
        while IFS= read -r owned_path; do
            [[ -n "$owned_path" ]] || continue
            owners["$owned_path"]="$entry"
        done < <(
            python3 - "$PATCHES_DIR/$entry" <<'PY'
import pathlib
import re
import sys

pattern = re.compile(r'^diff --git a/(.+?) b/(.+)$')
seen = set()
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    match = pattern.match(line)
    if not match:
        continue
    left, right = match.groups()
    candidates = []
    if left != '/dev/null':
        candidates.append(left)
    if right != '/dev/null' and right != left:
        candidates.append(right)
    for candidate in candidates:
        if candidate not in seen:
            seen.add(candidate)
            print(candidate)
PY
        )
    done

    for add_path in "${ADD_FILES[@]:-}"; do
        [[ -n "$add_path" ]] || continue
        if [[ -n "${owners[$add_path]:-}" ]]; then
            die "--add-file path '$add_path' is already owned by ${owners[$add_path]}"
        fi
    done
}

load_pinned_tag() {
    [[ -f "$AEROSPACE_VERSION_FILE" ]] || die "aerospace_version.txt not found at $AEROSPACE_VERSION_FILE"
    PINNED_TAG="v$(<"$AEROSPACE_VERSION_FILE")"
}

require_live_tree() {
    [[ -d "$LIVE_TREE/.git" ]] || die "Live AeroSpace checkout not found at $LIVE_TREE. Run ./utils/refresh-workspace.sh first."
}

clone_pinned_tree() {
    local destination="$1"
    git clone --quiet "$LIVE_TREE" "$destination" >/dev/null 2>&1
    git -C "$destination" reset --hard "$PINNED_TAG" --quiet
    git -C "$destination" clean -fd --quiet >/dev/null
}

apply_patch_file() {
    local patch_path="$1"
    local tree="$2"
    local mode="${3:-apply}"
    local reverse="${4:-0}"
    local output_file
    output_file="$(mktemp "$TEMP_DIR/patch-output.XXXXXX")"

    local args=("-p1" "--ignore-whitespace" "--no-backup-if-mismatch" "--fuzz=0" "-i" "$patch_path" "-d" "$tree")
    [[ "$mode" == "dry-run" ]] && args+=("--dry-run")
    [[ "$reverse" == "1" ]] && args+=("-R")

    if ! "$PATCH_BIN" "${args[@]}" >"$output_file" 2>&1; then
        sed 's/^/   /' "$output_file" >&2 || true
        rm -f "$output_file"
        return 1
    fi
    rm -f "$output_file"
}

apply_series_slice() {
    local tree="$1"
    shift
    local entry patch_path
    for entry in "$@"; do
        patch_path="$PATCHES_DIR/$entry"
        if ! apply_patch_file "$patch_path" "$tree" apply 0; then
            die "Failed to apply $entry while constructing temporary tree"
        fi
    done
}

copy_filtered_tree() {
    local source="$1"
    local destination="$2"
    mkdir -p "$destination"
    local args=("-a" "--delete")
    local exclude
    for exclude in "${ARTIFACT_EXCLUDES[@]}"; do
        args+=("--exclude=$exclude")
    done
    rsync "${args[@]}" "$source/" "$destination/" >/dev/null
}

collect_delta_paths() {
    python3 - "$1" "$2" "${ARTIFACT_EXCLUDES[@]}" <<'PY'
import hashlib
import os
import pathlib
import sys

left = pathlib.Path(sys.argv[1])
right = pathlib.Path(sys.argv[2])
excludes = sys.argv[3:]

def is_excluded(rel: str) -> bool:
    if rel in ('', '.'):
        return False
    for item in excludes:
        if rel == item or rel.startswith(item + '/'):
            return True
    return False

def digest(path: pathlib.Path) -> str:
    if path.is_symlink():
        return f"symlink:{path.readlink()}"
    h = hashlib.sha256()
    with path.open('rb') as fh:
        for chunk in iter(lambda: fh.read(65536), b''):
            h.update(chunk)
    return h.hexdigest()

def snapshot(root: pathlib.Path):
    state = {}
    for current_root, dirnames, filenames in os.walk(root):
        rel_root = os.path.relpath(current_root, root)
        rel_root = '' if rel_root == '.' else rel_root.replace('\\', '/')
        dirnames[:] = [d for d in dirnames if not is_excluded('/'.join(filter(None, [rel_root, d])))]
        for filename in filenames:
            rel = '/'.join(filter(None, [rel_root, filename]))
            if is_excluded(rel):
                continue
            path = pathlib.Path(current_root, filename)
            state[rel] = digest(path)
    return state

left_state = snapshot(left)
right_state = snapshot(right)
for rel in sorted(set(left_state) | set(right_state)):
    if left_state.get(rel) != right_state.get(rel):
        print(rel)
PY
}

copy_allowed_snapshot() {
    local source="$1"
    local destination="$2"
    shift 2
    mkdir -p "$destination"
    local path src_path dest_path
    for path in "$@"; do
        src_path="$source/$path"
        dest_path="$destination/$path"
        if [[ -f "$src_path" ]]; then
            mkdir -p "$(dirname "$dest_path")"
            cp "$src_path" "$dest_path"
        fi
    done
}

generate_patch_body() {
    local left_tree="$1"
    local right_tree="$2"
    python3 - "$left_tree" "$right_tree" "${ALLOWED_FILES[@]}" <<'PY'
import difflib
import pathlib
import sys

left_root = pathlib.Path(sys.argv[1])
right_root = pathlib.Path(sys.argv[2])
paths = sys.argv[3:]

def read_lines(path: pathlib.Path):
    if not path.exists():
        return []
    return path.read_text(encoding='utf-8', errors='surrogateescape').splitlines(keepends=True)

chunks = []
for rel in paths:
    left_path = left_root / rel
    right_path = right_root / rel
    left_exists = left_path.exists()
    right_exists = right_path.exists()

    if not left_exists and not right_exists:
        continue

    left_lines = read_lines(left_path)
    right_lines = read_lines(right_path)
    if left_exists and right_exists and left_lines == right_lines:
        continue

    chunk = [f"diff --git a/{rel} b/{rel}"]
    if not left_exists:
        chunk.append("new file mode 100644")
        fromfile = "/dev/null"
        tofile = f"b/{rel}"
    elif not right_exists:
        chunk.append("deleted file mode 100644")
        fromfile = f"a/{rel}"
        tofile = "/dev/null"
    else:
        fromfile = f"a/{rel}"
        tofile = f"b/{rel}"

    diff_lines = [
        line.rstrip('\n')
        for line in difflib.unified_diff(
            left_lines,
            right_lines,
            fromfile=fromfile,
            tofile=tofile,
            lineterm="",
        )
    ]

    chunk.extend(diff_lines)
    chunks.append("\n".join(chunk))

if chunks:
    print("\n\n".join(chunks))
PY
}

compare_allowed_paths() {
    python3 - "$1" "$2" "$3" <<'PY'
import hashlib
import pathlib
import sys

left = pathlib.Path(sys.argv[1])
right = pathlib.Path(sys.argv[2])
paths = [line for line in pathlib.Path(sys.argv[3]).read_text().splitlines() if line]

def digest(path: pathlib.Path):
    if not path.exists():
        return None
    h = hashlib.sha256()
    with path.open('rb') as fh:
        for chunk in iter(lambda: fh.read(65536), b''):
            h.update(chunk)
    return h.hexdigest()

for rel in paths:
    left_hash = digest(left / rel)
    right_hash = digest(right / rel)
    if left_hash != right_hash:
        print(rel)
PY
}

write_list_file() {
    local list_file="$1"
    shift
    : >"$list_file"
    local item
    for item in "$@"; do
        printf '%s\n' "$item" >>"$list_file"
    done
}

main() {
    parse_args "$@"
    require_cmd git
    require_cmd python3
    require_cmd rsync
    require_live_tree
    resolve_patch_bin
    load_pinned_tag
    load_series
    resolve_target_patch
    split_series
    extract_summary_prefix
    extract_owned_files
    normalize_add_files
    check_add_file_collisions
    build_allowed_files

    info "Target patch $TARGET_ENTRY"
    info "Owned path count: ${#OWNED_FILES[@]}"
    info "Explicit add-file count: ${#ADD_FILES[@]}"
    info "Allowed path count: ${#ALLOWED_FILES[@]}"

    TEMP_DIR="$(mktemp -d)"
    info "Using temporary workspace $TEMP_DIR"

    local tree_full="$TEMP_DIR/tree_full"
    local tree_a="$TEMP_DIR/tree_a"
    local tree_b="$TEMP_DIR/tree_b"
    local tree_verify="$TEMP_DIR/tree_verify"
    local generated_patch_tmp="$TEMP_DIR/generated.patch"
    local allowed_list_file="$TEMP_DIR/allowed-files.txt"

    clone_pinned_tree "$tree_full"
    apply_series_slice "$tree_full" "${SERIES_ENTRIES[@]}"

    local diff_paths=()
    mapfile -t diff_paths < <(collect_delta_paths "$LIVE_TREE" "$tree_full")
    info "Live-tree delta path count: ${#diff_paths[@]}"

    local unrelated=()
    local path allowed
    for path in "${diff_paths[@]}"; do
        allowed=0
        for candidate in "${ALLOWED_FILES[@]}"; do
            if [[ "$candidate" == "$path" ]]; then
                allowed=1
                break
            fi
        done
        if ((allowed == 0)); then
            unrelated+=("$path")
        fi
    done

    if ((${#unrelated[@]} > 0)); then
        printf '❌ ERROR: live AeroSpace checkout has unrelated edits outside the allowed patch surface:\n' >&2
        printf '   Target patch: %s\n' "$TARGET_ENTRY" >&2
        printf '   Total live-tree delta paths: %s\n' "${#diff_paths[@]}" >&2
        printf '   Unrelated path count: %s\n' "${#unrelated[@]}" >&2
        print_path_block '   Owned paths:' "${OWNED_FILES[@]}"
        print_path_block '   Explicit --add-file paths:' "${ADD_FILES[@]}"
        print_path_block '   Allowed paths:' "${ALLOWED_FILES[@]}"
        for path in "${unrelated[@]}"; do
            printf '   - %s\n' "$path" >&2
        done
        printf '   Re-run with --add-file for intended new owned paths, or audit live checkout drift.\n' >&2
        exit 1
    fi

    clone_pinned_tree "$tree_a"
    apply_series_slice "$tree_a" "${BEFORE_PATCHES[@]}"

    if ! apply_patch_file "$TARGET_PATCH_FILE" "$tree_a" dry-run 0; then
        die "Target patch $TARGET_ENTRY does not replay cleanly against its pre-target base. Run an ownership/provenance audit before regenerating it."
    fi

    copy_filtered_tree "$LIVE_TREE" "$tree_b"

    local reverse_entry
    for ((idx = ${#AFTER_PATCHES[@]} - 1; idx >= 0; idx--)); do
        reverse_entry="${AFTER_PATCHES[$idx]}"
        if ! apply_patch_file "$PATCHES_DIR/$reverse_entry" "$tree_b" apply 1; then
            die "Failed to reverse-apply later patch $reverse_entry while constructing the target post-state"
        fi
    done

    local patch_body
    patch_body="$(generate_patch_body "$tree_a" "$tree_b")"
    local generated_patch
    if [[ -n "$SUMMARY_PREFIX" ]]; then
        generated_patch="$(printf '%s\n\n%s' "$SUMMARY_PREFIX" "$patch_body")"
    else
        generated_patch="$patch_body"
    fi

    if [[ -z "$patch_body" ]]; then
        die "Regeneration produced an empty patch for $TARGET_ENTRY. Run an ownership/provenance audit before replacing it."
    fi

    if [[ "$generated_patch" == "$(cat "$TARGET_PATCH_FILE")" ]]; then
        printf 'patch unchanged\n'
        exit 0
    fi

    printf '%s\n' "$generated_patch" >"$generated_patch_tmp"

    if ! apply_patch_file "$generated_patch_tmp" "$tree_a" dry-run 0; then
        die "Regenerated patch failed validation against the pre-target base"
    fi

    clone_pinned_tree "$tree_verify"
    apply_series_slice "$tree_verify" "${BEFORE_PATCHES[@]}"
    apply_patch_file "$generated_patch_tmp" "$tree_verify" apply 0 || die "Regenerated patch failed real apply in verification tree"
    apply_series_slice "$tree_verify" "${AFTER_PATCHES[@]}"

    write_list_file "$allowed_list_file" "${ALLOWED_FILES[@]}"
    local mismatches=()
    mapfile -t mismatches < <(compare_allowed_paths "$tree_verify" "$LIVE_TREE" "$allowed_list_file")
    if ((${#mismatches[@]} > 0)); then
        printf '❌ ERROR: replay verification did not reproduce the expected final state for allowed paths:\n' >&2
        for path in "${mismatches[@]}"; do
            printf '   - %s\n' "$path" >&2
        done
        exit 1
    fi

    mv "$generated_patch_tmp" "$TARGET_PATCH_FILE"
    info "Regenerated $TARGET_ENTRY"
}

main "$@"
