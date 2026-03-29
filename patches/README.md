# Patch Stack

This directory is the source of truth for fork behavior.

- `series` - ordered patch list
- `hyprspace/` - fork-owned product patches
- `upstream-fixes/` - isolated upstream-compatible fix patches

Rules:

- one behavior or one narrow seam per patch
- keep names descriptive and stable
- keep patch order aligned with dependency order
- do not hide cleanup or formatting changes inside behavior patches
- if you are refining behavior already owned by an existing patch, replace that patch file instead of stacking a duplicate follow-up patch
- decide patch ownership before editing `AeroSpace/`; never make changes first and classify them later

How to replace an existing patch safely:

1. identify the owning patch in `patches/series` before editing
2. prove the change in `AeroSpace/`
3. regenerate that same patch file with `bash ./devutils/regenerate-patch.sh <existing-patch-name>`
4. if the regenerated patch intentionally owns one new file, re-run with `--add-file <path>` for that path
5. the helper must rewrite the same patch as a plain diff that begins at `diff --git ...` and preserves any leading `# Summary: ...` metadata
6. do not append anything to `patches/series`
7. rebuild from `./utils/refresh-workspace.sh` so the patch stack, not the dirty checkout, is the source of truth

See `docs/dev/workflow.md` for the full decision workflow and the exact replace-vs-new-patch rules.
