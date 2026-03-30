# Hyprspace Development

This is the only developer and maintainer doc in the repo.

Code, scripts, manifests, and patch files are the source of truth. This file only records the repo-specific things that are easy to miss.

## What matters

- `AeroSpace/` is ephemeral. Rebuild it from patch truth; do not treat it as long-term source.
- `patches/series` and the referenced patch files are the source of truth for product behavior.
- `docs/patches.md` is generated. Do not hand-edit it.
- `artifacts/docs/` contains the doc sources that are shipped to public surfaces and release artifacts.

## Owner paths

- Baseline state: `./scripts/verify/repo-state-table.sh`
- Rebuild patched workspace: `./scripts/patch/refresh-workspace.sh`
- Local install/bootstrap: `./scripts/install/install-local.sh`
- Patch validation: `PATCH_BIN="$(command -v gpatch)" bash scripts/patch/validate-patches.sh`
- Regenerate patch index: `python3 scripts/internal/generate-patches-doc.py`
- Release/public-surface mapping: `scripts/internal/public-release-surface-manifest.json`
- Release publish precheck: `./scripts/release/precheck.sh <version>`
- Real release publish: `./scripts/release/publish-hyprspace-release.sh <version>`

## Patch rules

- Keep the same behavior in the same patch unless there is a real ownership split.
- Keep patch names descriptive and stable.
- Keep patch order aligned with dependency order.
- Do not hide cleanup or formatting changes inside behavior patches.
- Decide patch ownership before editing `AeroSpace/`; never make changes first and classify them later.
- When updating an existing patch, use `./scripts/patch/regenerate-patch.sh <patch-name>`.
- If you are refining behavior already owned by an existing patch, replace that patch file instead of stacking a duplicate follow-up patch.
- If the regenerated patch intentionally owns one new file, rerun with `--add-file <path>` for that path.
- The helper must rewrite the same patch as a plain diff that begins at `diff --git ...` and preserves any leading `# Summary: ...` metadata.
- Do not append anything to `patches/series` when replacing an existing patch.
- After changing patch truth, rerun workspace refresh and patch validation.

## Config internals

Config lookup order:
1. `~/.config/hyprspace/config.toml`
2. `~/.hyprspace.toml`
3. `~/Library/Application Support/Hyprspace/config.toml`

Non-obvious facts:
- the starter config template lives at `artifacts/configs/hyprspace-config.toml`
- the installed reference config lives at `~/.config/hyprspace/docs/default-config.toml`
- the reference config is never treated as a live config candidate

Implementation:
- `AeroSpace/Sources/AppBundle/config/ConfigFile.swift`
- `AeroSpace/Sources/AppBundle/config/parseConfig.swift`

User-facing config and legal docs live in `artifacts/docs/`.
Public cask generation lives in `AeroSpace/script/build-brew-cask.sh` and should keep homepage/verified aligned with the public release surfaces.
