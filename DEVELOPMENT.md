# Hyprspace Development

## Base structure

- `AeroSpace/` is ephemeral. Rebuild it from patch truth; do not treat it as long-term source.
- `patches/series` and the referenced patch files are the source of truth for product behavior.
- `docs/patches.md` is generated. Do not hand-edit it.
- `artifacts/docs/` contains the doc sources that are shipped to public surfaces and release artifacts.

## Owner paths

- Baseline state: `./scripts/verify/repo-state-table.sh`
- Mise wrapper: `mise run verify:repo-state`
- Rebuild patched workspace: `./scripts/patch/refresh-workspace.sh`
- Mise wrapper: `mise run patch:refresh-workspace`
- Local install/bootstrap: `./scripts/install/install-local.sh`
- Mise wrapper: `mise run install:local`
- Patch validation: `PATCH_BIN="$(command -v gpatch)" bash scripts/patch/validate-patches.sh`
- Mise wrapper: `mise run patch:validate`
- Regenerate patch index: `python3 scripts/internal/generate-patches-doc.py`
- Release/public-surface mapping: `scripts/internal/public-release-surface-manifest.json`
- Release publish pre-release-checks: `./scripts/release/pre-release-checks.sh <version>`
- Real release publish: `./scripts/release/publish-hyprspace-release.sh <version>`

## Mise tasks

- Public script entry points are available via `mise tasks`.
- Prefer the task names for routine use: `mise run install:local`, `mise run patch:refresh-workspace`, `mise run patch:validate`, `mise run release:preflight -- <version>`, `mise run release:publish -- <version>`, `mise run verify:run-all-tests`.
- Keep the release flow details inside `scripts/release/publish-hyprspace-release.sh`. `DEVELOPMENT.md` should only point to the task or script to run, not duplicate the release procedure.

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

## Init flow

### Changing default keybindings

Edit `artifacts/configs/hyprspace-config.toml`. This is the starter config template written to `~/.config/hyprspace/config.toml` on first init. App placeholders (`{{terminal}}`, `{{music}}`, `{{browser}}`) are substituted at install time based on the user's selections.

### Adding or changing installable tools

Two files own this:

**`libexec/hyprspace-init/step-metadata.sh`** — declares what exists:
- `OPTIONAL_STEP_KEYS` — steps shown in the TUI (all selected by default)
- `MANDATORY_STEP_KEYS` — always applied, not shown in TUI
- `step_label()` / `step_key_for_label()` — display names
- `*_app_choices()` / `default_*_app()` — terminal, music, browser menus

**`scripts/internal/setup-dependencies.sh`** — declares what gets installed:
- Maps selected steps and app choices to `brew install` / `brew install --cask` calls
- All installs are idempotent (skips if already installed)

To add a new optional tool:
1. Add the key to `OPTIONAL_STEP_KEYS` and add its `step_label()` / `step_key_for_label()` cases in `step-metadata.sh`
2. Add the brew install in `setup-dependencies.sh`
3. Add `--with-<key>` / `--without-<key>` handling and the setup call in `libexec/hyprspace-init/apply-init-selections.sh`
4. Write `scripts/internal/setup-<key>.sh` for any config work beyond the install
5. Add cleanup to `libexec/hyprspace-deinit/apply-deinit-selections.sh`

To add a new app choice (e.g. a new browser option):
1. Add the value to the relevant `*_app_choices()` function and add a `validate_*_app()` case in `step-metadata.sh`
2. Add the conditional brew install in `setup-dependencies.sh`

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
