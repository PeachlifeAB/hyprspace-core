#!/bin/bash

repo_state_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_state_root_dir="$(cd "${repo_state_script_dir}/../.." && pwd)"

repo_state_sanitize() {
    printf '%s' "${1:-}" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//; s/\|/\\|/g'
}

repo_state_is_git_repo() {
    git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

repo_state_upstream_ref() {
    local repo="$1"
    git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true
}

repo_state_fetch_upstream() {
    local repo="$1"
    local upstream="$2"
    if [ -z "$upstream" ]; then
        return 0
    fi
    local remote="${upstream%%/*}"
    local branch="${upstream#*/}"
    if [ "$remote" = "$branch" ]; then
        return 0
    fi
    git -C "$repo" fetch --quiet "$remote" "$branch" >/dev/null 2>&1
}

repo_state_show() {
    local repo="$1"
    local ref="$2"
    local format="$3"
    git -C "$repo" show -s --format="$format" "$ref" 2>/dev/null || true
}

repo_state_default_homebrew_prefix() {
    if command -v brew >/dev/null 2>&1; then
        brew --prefix 2>/dev/null || true
    elif [ "$(uname -m)" = "arm64" ]; then
        printf '%s\n' "/opt/homebrew"
    else
        printf '%s\n' "/usr/local"
    fi
}

print_path_timestamps() {
    local path="$1"
    local stat_output
    if stat_output="$(stat -f 'birth=%SB modified=%Sm' -t '%Y-%m-%dT%H:%M:%S%z' "$path" 2>/dev/null)"; then
        echo "[artifact]   timestamps=$stat_output"
    fi
}

print_executable_version() {
    local path="$1"
    python3 - "$path" <<'PY'
import subprocess
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.exists() or not path.is_file():
    sys.exit(0)

try:
    proc = subprocess.run([str(path), '--version'], capture_output=True, text=True, timeout=3)
    out = (proc.stdout or proc.stderr or '').strip().splitlines()
    if out:
        print(f"[artifact]   version={out[0]}")
except Exception:
    pass
PY
}

print_bundle_version() {
    local app_path="$1"
    local plist="$app_path/Contents/Info.plist"
    local short_version build_version
    if [ ! -f "$plist" ]; then
        return 0
    fi
    short_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist" 2>/dev/null || true)"
    build_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist" 2>/dev/null || true)"
    if [ -n "$short_version" ] || [ -n "$build_version" ]; then
        echo "[artifact]   bundle_version=${short_version:-unknown} build=${build_version:-unknown}"
    fi
}

print_command_state() {
    local name="$1"
    echo "[artifact] command=$name"
    if command -v "$name" >/dev/null 2>&1; then
        local resolved real
        resolved="$(command -v "$name")"
        echo "[artifact]   command -v=$resolved"
        echo "[artifact]   ls -ld:"
        ls -ld "$resolved"
        print_path_timestamps "$resolved"
        if real="$(realpath "$resolved" 2>/dev/null)"; then
            echo "[artifact]   realpath=$real"
            print_executable_version "$real"
        else
            print_executable_version "$resolved"
        fi
    else
        echo "[artifact]   command -v=<missing>"
    fi
}

print_path_state() {
    local label="$1"
    local path="$2"
    local real
    echo "[artifact] path=$label value=$path"
    if [ -e "$path" ] || [ -L "$path" ]; then
        echo "[artifact]   ls -ld:"
        ls -ld "$path"
        print_path_timestamps "$path"
        if real="$(realpath "$path" 2>/dev/null)"; then
            echo "[artifact]   realpath=$real"
        fi
        if [ -d "$path" ] && [[ "$path" == *.app ]]; then
            print_bundle_version "$path"
        elif [ -x "$path" ] && [ ! -d "$path" ]; then
            print_executable_version "$path"
        fi
        xattr -l "$path" 2>/dev/null || echo "[artifact]   xattr=<none>"
        if [ -d "$path" ]; then
            echo "[artifact]   ls -la:"
            ls -la "$path"
        fi
    else
        echo "[artifact]   state=<missing>"
    fi
}

print_public_install_artifact_state() {
    local phase="$1"
    local build_version="$2"
    local nested_cli="/opt/homebrew/Caskroom/hyprspace/${build_version}/Hyprspace-v${build_version}/libexec/hyprspace-cli"
    echo "[artifact-state:${phase}] generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    print_command_state hyprspace
    print_command_state sketchybar
    print_command_state borders
    print_path_state Hyprspace.app /Applications/Hyprspace.app
    print_path_state homebrew-hyprspace-link /opt/homebrew/bin/hyprspace
    print_path_state homebrew-hyprspace-caskroom /opt/homebrew/Caskroom/hyprspace
    print_path_state homebrew-hyprspace-cli "$nested_cli"
}

print_local_install_artifact_state() {
    local phase="$1"
    local install_prefix="$2"
    echo "[artifact-state:${phase}] generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    print_command_state hyprspace
    print_command_state sketchybar
    print_command_state borders
    print_path_state install-prefix-app "$install_prefix/Hyprspace.app"
    print_path_state install-prefix-bin "$install_prefix/bin/hyprspace"
    print_path_state install-prefix-cli "$install_prefix/libexec/hyprspace-cli"
}

print_home_config_state() {
    local phase="$1"
    local home_dir="$2"
    echo "[config-state:${phase}] generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    print_path_state hyprspace-config-toml "$home_dir/.config/hyprspace/config.toml"
    print_path_state hyprspace-docs-default-config "$home_dir/.config/hyprspace/docs/default-config.toml"
    print_path_state hyprspace-docs-readme "$home_dir/.config/hyprspace/docs/README.md"
    print_path_state hyprspace-docs-acknowledgments "$home_dir/.config/hyprspace/docs/ACKNOWLEDGMENTS.md"
    print_path_state sketchybar-config "$home_dir/.config/sketchybar/sketchybarrc"
    print_path_state sketchybar-plugin-hyprspace "$home_dir/.config/sketchybar/plugins/hyprspace_workspace.sh"
}

print_process_state() {
    local phase="$1"
    echo "[process-state:${phase}] generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    python3 <<'PY'
import subprocess

targets = {"Hyprspace", "AeroSpace", "hyprspace-cli", "sketchybar", "borders"}
ps = subprocess.run(
    ["ps", "-Ao", "pid=,lstart=,comm=,command="],
    capture_output=True,
    text=True,
    check=True,
).stdout.splitlines()

matches = []
for line in ps:
    parts = line.split(None, 7)
    if len(parts) < 8:
        continue
    pid = parts[0]
    lstart = " ".join(parts[1:6])
    comm = parts[6]
    command = parts[7]
    if comm in targets:
        matches.append((pid, lstart, comm, command))

if not matches:
    print("[process] tracked_processes=<none>")
else:
    for pid, lstart, comm, command in matches:
        print(f"[process] pid={pid} started={lstart} comm={comm} command={command}")
PY
}

print_current_system_artifact_state() {
    local phase="$1"
    local build_version=''
    local caskroom_root='/opt/homebrew/Caskroom/hyprspace'

    if [ -f "$repo_state_root_dir/version.txt" ]; then
        build_version="$(tr -d '\r' <"$repo_state_root_dir/version.txt")"
    fi

    echo "[artifact-state:${phase}] generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    print_command_state hyprspace
    print_command_state sketchybar
    print_command_state borders
    print_path_state Hyprspace.app /Applications/Hyprspace.app
    print_path_state homebrew-hyprspace-link /opt/homebrew/bin/hyprspace
    print_path_state homebrew-hyprspace-caskroom "$caskroom_root"
    if [ -n "$build_version" ]; then
        print_path_state homebrew-hyprspace-cli "/opt/homebrew/Caskroom/hyprspace/${build_version}/Hyprspace-v${build_version}/libexec/hyprspace-cli"
    fi
    print_home_config_state "$phase" "$HOME"
    print_process_state "$phase"
}

print_patch_input_state() {
    local phase="$1"
    local series_file="$repo_state_root_dir/patches/series"
    local checkout_dir="$repo_state_root_dir/AeroSpace"

    echo "[patch-input-state:${phase}] generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    python3 - "$series_file" "$repo_state_root_dir/patches" "$checkout_dir" <<'PY'
from __future__ import annotations

from collections import Counter
from pathlib import Path
import re
import sys

series_file = Path(sys.argv[1])
patches_dir = Path(sys.argv[2])
checkout_dir = Path(sys.argv[3])

print(f"[patch-input] series_file={series_file}")
print(f"[patch-input] checkout_dir={checkout_dir}")

if not series_file.exists():
    print("[patch-input] series_state=<missing>")
    raise SystemExit(0)

entries: list[str] = []
for raw_line in series_file.read_text().splitlines():
    line = raw_line.split("#", 1)[0].strip()
    if line:
        entries.append(line)

print(f"[patch-input] entry_count={len(entries)}")
for index, entry in enumerate(entries, start=1):
    print(f"[patch-input] series[{index:02d}]={entry}")
duplicates = [entry for entry, count in Counter(entries).items() if count > 1]
if duplicates:
    print(f"[patch-input] duplicate_entries={', '.join(duplicates)}")
else:
    print("[patch-input] duplicate_entries=<none>")

missing_files: list[str] = []
format_issues: list[str] = []
missing_target_issues: list[str] = []

mailbox_re = re.compile(r'^(From [0-9a-f]{40} |From: |Date: |Subject: |---$|-- $|[0-9]+\.[0-9]+(\.[0-9]+)? \(Apple Git-)')

for entry in entries:
    patch_file = patches_dir / entry
    if not patch_file.exists():
        missing_files.append(entry)
        continue

    text = patch_file.read_text()
    lines = text.splitlines()

    first_payload = None
    for line in lines:
        if line.startswith('# Summary:') or not line.strip():
            continue
        first_payload = line
        break
    if first_payload is None or not first_payload.startswith('diff --git '):
        format_issues.append(f"{entry}:first-payload-not-diff")

    for idx, line in enumerate(lines, start=1):
        if mailbox_re.match(line):
            format_issues.append(f"{entry}:mailbox-marker:{idx}")

    current = {
        "old_path": None,
        "new_path": None,
        "new_file_mode": False,
        "old_marker": None,
    }

    def finalize_current() -> None:
        if current["old_path"] is None or current["new_path"] is None:
            return
        if current["new_file_mode"] or current["old_marker"] == '/dev/null':
            return
        if not checkout_dir.exists():
            return
        old_target = checkout_dir / current["old_path"]
        if not old_target.exists():
            missing_target_issues.append(f"{entry}:{current['new_path']}")

    for line in lines:
        if line.startswith('diff --git '):
            finalize_current()
            m = re.match(r'^diff --git a/(.+) b/(.+)$', line)
            current["old_path"] = m.group(1) if m else None
            current["new_path"] = m.group(2) if m else None
            current["new_file_mode"] = False
            current["old_marker"] = None
        elif line.startswith('new file mode '):
            current["new_file_mode"] = True
        elif line.startswith('--- '):
            current["old_marker"] = line[4:].strip()
        elif line.startswith('+++ '):
            pass
    finalize_current()

if missing_files:
    print(f"[patch-input] missing_patch_files={', '.join(missing_files)}")
else:
    print("[patch-input] missing_patch_files=<none>")

if format_issues:
    print(f"[patch-input] format_issues={'; '.join(format_issues)}")
else:
    print("[patch-input] format_issues=<none>")

if missing_target_issues:
    print(f"[patch-input] missing_checkout_targets_without_new_file_mode={'; '.join(missing_target_issues)}")
else:
    print("[patch-input] missing_checkout_targets_without_new_file_mode=<none>")
PY
}

repo_state_row() {
    local name="$1"
    local repo="$2"
    local repo_display

    if ! repo_state_is_git_repo "$repo"; then
        echo "[repo] $name  path=$repo  state=missing"
        return 0
    fi

    repo_display="$(cd "$repo" && pwd -P)"

    local branch dirty local_hash local_date local_subject upstream remote_hash remote_date remote_subject fetch_status
    branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || echo DETACHED)"
    if [ -n "$(git -C "$repo" status --short 2>/dev/null)" ]; then
        dirty='dirty'
    else
        dirty='clean'
    fi

    local_hash="$(repo_state_show "$repo" HEAD '%h')"
    local_date="$(repo_state_show "$repo" HEAD '%cI')"
    local_subject="$(repo_state_show "$repo" HEAD '%s')"

    upstream="$(repo_state_upstream_ref "$repo")"
    if [ -n "$upstream" ]; then
        if repo_state_fetch_upstream "$repo" "$upstream"; then
            fetch_status='proven'
            remote_hash="$(repo_state_show "$repo" "$upstream" '%h')"
            remote_date="$(repo_state_show "$repo" "$upstream" '%cI')"
            remote_subject="$(repo_state_show "$repo" "$upstream" '%s')"
        else
            fetch_status='unproven(fetch failed)'
            remote_hash='unproven'
            remote_date='unproven'
            remote_subject='unproven'
        fi
    else
        upstream='none'
        fetch_status='unproven(no upstream)'
        remote_hash='unproven'
        remote_date='unproven'
        remote_subject='unproven'
    fi

    echo "[repo] $name"
    echo "  path=$repo_display"
    echo "  branch=$branch  dirty=$dirty"
    echo "  local   hash=${local_hash:-unknown}  date=${local_date:-unknown}  subject=${local_subject:-unknown}"
    echo "  remote  ref=$upstream  hash=${remote_hash}  date=${remote_date}  subject=${remote_subject}  sync=$fetch_status"
}

print_default_repo_state_table() {
    local label="${1:-current}"
    print_repo_state_table "$label" \
        source "$repo_state_root_dir" \
        tap "$repo_state_root_dir/../homebrew-hyprspace" \
        releases "$repo_state_root_dir/../hyprspace-releases"
}

print_repo_state_table() {
    local label="$1"
    shift

    echo "[repo-state:${label}] generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    while [ "$#" -ge 2 ]; do
        local name="$1"
        local repo="$2"
        shift 2
        repo_state_row "$name" "$repo"
    done
}

print_env_and_symlink_state() {
    local phase="$1"
    echo "[env-state:${phase}] generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # PATH
    echo "[env] PATH=$PATH"

    # brew prefix
    local brew_prefix
    brew_prefix="$(repo_state_default_homebrew_prefix)"
    echo "[env] brew_prefix=$brew_prefix"

    local installed_cli="$brew_prefix/bin/hyprspace"

    if [ -L "$installed_cli" ]; then
        local target
        target="$(readlink "$installed_cli")"
        if [ -e "$installed_cli" ]; then
            echo "[env] installed-cli=$installed_cli -> $target (valid)"
        else
            echo "[env] installed-cli=$installed_cli -> $target (STALE - target missing)"
        fi
    elif [ -e "$installed_cli" ]; then
        echo "[env] installed-cli=$installed_cli (not a symlink, regular file)"
    else
        echo "[env] installed-cli=$installed_cli (absent)"
    fi

    local legacy_local_bin="$HOME/.local/bin/hyprspace"
    if [ -L "$legacy_local_bin" ]; then
        local target
        target="$(readlink "$legacy_local_bin")"
        if [ -e "$legacy_local_bin" ]; then
            echo "[env] legacy-local-bin=$legacy_local_bin -> $target (valid)"
        else
            echo "[env] legacy-local-bin=$legacy_local_bin -> $target (STALE - target missing)"
        fi
    elif [ -e "$legacy_local_bin" ]; then
        echo "[env] legacy-local-bin=$legacy_local_bin (not a symlink, regular file)"
    else
        echo "[env] legacy-local-bin=$legacy_local_bin (absent)"
    fi

    # duplicate server process check
    python3 <<'PY'
import subprocess
from collections import Counter

targets = {"Hyprspace", "AeroSpace"}
ps = subprocess.run(
    ["ps", "-Ao", "pid=,comm="],
    capture_output=True, text=True, check=True,
).stdout.splitlines()

counts: Counter = Counter()
for line in ps:
    parts = line.split(None, 1)
    if len(parts) == 2 and parts[1].strip() in targets:
        counts[parts[1].strip()] += 1

for name, count in counts.items():
    if count > 1:
        print(f"[env] duplicate-server-WARNING={name} running {count} times")
    else:
        print(f"[env] server-count={name} count={count}")

if not counts:
    print("[env] server-count=<none running>")

# which server socket/binary the CLI resolves to
try:
    result = subprocess.run(
        ["hyprspace", "--version"],
        capture_output=True, text=True,
    )
    out = (result.stdout or result.stderr or "").strip().splitlines()
    version_line = out[0] if out else "<no output>"
    print(f"[env] hyprspace-cli-version={version_line}")
except FileNotFoundError:
    print("[env] hyprspace-cli-version=<missing command>")
PY
}

print_accessibility_state() {
    local phase="$1"
    local app_binary="/Applications/Hyprspace.app/Contents/MacOS/Hyprspace"
    local brew_prefix cli_wrapper cli_runtime
    brew_prefix="$(repo_state_default_homebrew_prefix)"
    cli_wrapper="$brew_prefix/bin/hyprspace"
    cli_runtime="/Applications/Hyprspace.app/Contents/Resources/libexec/hyprspace-cli"

    echo "[accessibility-state:${phase}] generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    print_accessibility_probe() {
        local label="$1"
        local path="$2"
        echo "[accessibility] surface=$label path=$path"
        if [ ! -x "$path" ]; then
            echo "[accessibility]   state=<missing-or-not-executable>"
            return 0
        fi
        while IFS= read -r line; do
            echo "[accessibility]   $line"
        done < <("$path" --accessibility-status 2>&1 || true)
    }

    print_accessibility_probe installed-app "$app_binary"
    print_accessibility_probe resolved-cli "$cli_wrapper"
    print_accessibility_probe cli-runtime "$cli_runtime"
}

print_journal_tail() {
    local journal="$repo_state_root_dir/journal.md"
    echo "[journal:tail100] generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [ -f "$journal" ]; then
        tail -n 100 "$journal"
    else
        echo "<journal.md not found>"
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    print_default_repo_state_table "${1:-current}"
    print_patch_input_state "${1:-current}"
    print_current_system_artifact_state "${1:-current}"
    print_env_and_symlink_state "${1:-current}"
    print_accessibility_state "${1:-current}"
    print_journal_tail
fi
