# Project-specific behavior overrides

## Patch-stack discipline (HARD RULE)

This repo is patch-controlled. `AeroSpace/` is ephemeral. `patches/series` + `patches/` are the source of truth.

**Before ANY edit, classify the work via Step 0 of `.claude/skills/patch-based-development/SKILL.md`:**

1. **Root-plane?** (README, tests/, scripts/, docs/, libexec/, artifacts/, patches/) → edit directly, no patch export.
2. **Inside `AeroSpace/`?** → patch-controlled. Identify the owning patch in `patches/series`.
3. **Pick scenario A/B/C/D** before editing a single file.

**Never edit `AeroSpace/` first and classify later.**

After any edit inside `AeroSpace/`:

- `mise run patch:regenerate -- <patch-name>` (Scenario A) or generate-and-append-to-series (Scenario B)
- `mise run patch:validate`
- `mise run patch:refresh-workspace` — must complete clean from scratch
- If patches added/removed: `python3 scripts/internal/generate-patches-doc.py` and commit

## Test impact rule

When changing `OPTIONAL_STEP_KEYS` in `libexec/hyprspace-init/step-metadata.sh`, update these tests:

- `tests/test-hyprspace-init-defaults.sh` (asserts the full default key list)
- `tests/test-hyprspace-init-selection-preview.sh` (asserts apply_flags output for deselected steps)

## Useful tooling notes

- `mise tasks` lists all repo task wrappers; prefer `mise run <task>` over calling scripts directly.
