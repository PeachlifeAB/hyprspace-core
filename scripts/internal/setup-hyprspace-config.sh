#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_HOME="${HYPRSPACE_HOME_OVERRIDE:-$HOME}"
CONFIG_DIR="${HYPRSPACE_CONFIG_DIR_OVERRIDE:-$SCRIPT_HOME/.config/hyprspace}"
PREFERRED_CONFIG_DEST="$CONFIG_DIR/config.toml"
DOCS_DIR="$CONFIG_DIR/docs"
REFERENCE_CONFIG_DEST="$DOCS_DIR/default-config.toml"
CONFIG_README_DEST="$DOCS_DIR/README.md"
ACKNOWLEDGMENTS_DEST="$DOCS_DIR/ACKNOWLEDGMENTS.md"
LEGACY_DOTFILE_DEST="$SCRIPT_HOME/.hyprspace.toml"
APP_SUPPORT_CONFIG_DEST="$SCRIPT_HOME/Library/Application Support/Hyprspace/config.toml"
enable_sketchybar="${HYPRSPACE_ENABLE_SKETCHYBAR:-1}"
enable_borders="${HYPRSPACE_ENABLE_BORDERS:-1}"
selected_terminal_app="${HYPRSPACE_SELECTED_TERMINAL_APP:-Ghostty}"
selected_music_app="${HYPRSPACE_SELECTED_MUSIC_APP:-Apple Music}"
selected_browser_app="${HYPRSPACE_SELECTED_BROWSER_APP:-Safari}"

render_starter_config() {
    local src="$1"
    local dest="$2"

    STARTER_CONFIG_SOURCE="$src" \
        STARTER_CONFIG_DEST="$dest" \
        STARTER_ENABLE_SKETCHYBAR="$enable_sketchybar" \
        STARTER_ENABLE_BORDERS="$enable_borders" \
        STARTER_SELECTED_TERMINAL_APP="$selected_terminal_app" \
        STARTER_SELECTED_MUSIC_APP="$selected_music_app" \
        STARTER_SELECTED_BROWSER_APP="$selected_browser_app" \
        python3 - <<'PY'
import re, sys
from pathlib import Path
from os import environ

src = Path(environ["STARTER_CONFIG_SOURCE"])
dest = Path(environ["STARTER_CONFIG_DEST"])
text = src.read_text()

# Conditional blocks: # {{#name}} ... # {{/name}}
# Remove the block (including markers) when disabled, strip markers when enabled.
sections = {
    "borders": environ["STARTER_ENABLE_BORDERS"] == "1",
    "sketchybar": environ["STARTER_ENABLE_SKETCHYBAR"] == "1",
}
for name, enabled in sections.items():
    pattern = re.compile(
        r"^# \{\{#" + re.escape(name) + r"\}\}\n(.*?)^# \{\{/" + re.escape(name) + r"\}\}\n",
        re.MULTILINE | re.DOTALL,
    )
    match = pattern.search(text)
    if match is None:
        print(f"ERROR: missing section marker {{{{#{name}}}}} in {src}", file=sys.stderr)
        sys.exit(1)
    if enabled:
        text = pattern.sub(match.group(1), text)
    else:
        text = pattern.sub("", text)

# Value placeholders: {{name}}
music_app = environ["STARTER_SELECTED_MUSIC_APP"]
values = {
    "terminal": environ["STARTER_SELECTED_TERMINAL_APP"],
    "browser": environ["STARTER_SELECTED_BROWSER_APP"],
    "music": "Music" if music_app == "Apple Music" else music_app,
}
remaining = set(re.findall(r"\{\{(\w+)\}\}", text))
missing = remaining - set(values.keys())
if missing:
    print(f"ERROR: unresolved placeholders in {src}: {missing}", file=sys.stderr)
    sys.exit(1)
for name, value in values.items():
    text = text.replace("{{" + name + "}}", value)

dest.write_text(text)
PY
}

existing_configs=()
for candidate in "$PREFERRED_CONFIG_DEST" "$LEGACY_DOTFILE_DEST" "$APP_SUPPORT_CONFIG_DEST"; do
    if [ -f "$candidate" ]; then
        existing_configs+=("$candidate")
    fi
done

if [ ${#existing_configs[@]} -gt 0 ]; then
    echo "-> Recognized configuration already exists. Skipping starter config injection to preserve user settings and avoid ambiguous config paths."
    for existing_config in "${existing_configs[@]}"; do
        echo "   - $existing_config"
    done
else
    echo "-> Injecting starter configuration to $PREFERRED_CONFIG_DEST..."
    mkdir -p "$CONFIG_DIR"
    render_starter_config "$ROOT_DIR/artifacts/configs/hyprspace-config.toml" "$PREFERRED_CONFIG_DEST"
fi

echo "-> Injecting documentation files to $DOCS_DIR..."
mkdir -p "$DOCS_DIR"
cp "$ROOT_DIR/AeroSpace/docs/config-examples/config.default.toml" "$REFERENCE_CONFIG_DEST"
cp "$ROOT_DIR/artifacts/configs/docs/README.md" "$CONFIG_README_DEST"
cp "$ROOT_DIR/artifacts/configs/docs/ACKNOWLEDGMENTS.md" "$ACKNOWLEDGMENTS_DEST"
