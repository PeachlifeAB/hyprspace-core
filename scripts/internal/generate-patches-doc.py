#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCHES_DIR = ROOT / "patches"
SERIES = PATCHES_DIR / "series"
OUT = ROOT / "docs" / "patches.md"


def title_from_name(name: str) -> str:
    base = name.removesuffix(".patch").replace("-", " ")
    return base


def parse_patch_metadata(path: Path):
    text = path.read_text()
    summary = None
    lines = text.splitlines()
    for line in lines:
        if line.startswith("# Summary: "):
            summary = line[len("# Summary: ") :].strip()
            break
    title = title_from_name(path.name)
    if summary is None:
        summary = "No summary metadata provided."
    return title, summary


def load_series():
    active = []
    for line in SERIES.read_text().splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        active.append(stripped)
    return active


def render():
    active = load_series()
    active_set = set(active)
    hyprspace_dir = PATCHES_DIR / "hyprspace"
    all_hyprspace = sorted(p.name for p in hyprspace_dir.glob("*.patch"))
    inactive = [
        f"hyprspace/{name}"
        for name in all_hyprspace
        if f"hyprspace/{name}" not in active_set
    ]

    lines = []
    lines.append("# Hyprspace Patches")
    lines.append("")
    lines.append(
        "> GENERATED FILE. Edit patch metadata in `patches/hyprspace/*.patch` and rerun `scripts/internal/generate-patches-doc.py`."
    )
    lines.append("")
    lines.append(
        "The active stack is the ordered list in `patches/series`. Each patch should provide leading `# Summary: ...` metadata, followed by a plain diff that begins at `diff --git ...`."
    )
    lines.append("")
    lines.append("## Active patch stack")
    lines.append("")
    for rel in active:
        path = PATCHES_DIR / rel
        if not path.exists():
            raise FileNotFoundError(
                f"Patch file listed in series not found: {path} (series entry: {rel!r})"
            )
        title, summary = parse_patch_metadata(path)
        lines.append(f"- `{rel}`")
        lines.append(f"  **{title}** — {summary}")
        lines.append("")
    lines.append("## Patch files not currently in `patches/series`")
    lines.append("")
    if inactive:
        for rel in inactive:
            path = PATCHES_DIR / rel
            title, summary = parse_patch_metadata(path)
            lines.append(f"- `{rel}`")
            lines.append(f"  **{title}** — {summary}")
            lines.append("")
    else:
        lines.append("- None.")
        lines.append("")
    lines.append("## Upstream-fix bucket")
    lines.append("")
    upstream = sorted((PATCHES_DIR / "upstream-fixes").glob("*.patch"))
    if upstream:
        for path in upstream:
            title, summary = parse_patch_metadata(path)
            rel = path.relative_to(PATCHES_DIR)
            lines.append(f"- `{rel}`")
            lines.append(f"  **{title}** — {summary}")
            lines.append("")
    else:
        lines.append("- `patches/upstream-fixes/` is currently empty.")
        lines.append("")
    OUT.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    render()
