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

## Init flow internals

`hyprspace init` is an interactive TUI that installs optional integrations and writes the starter config. The entry point is `libexec/hyprspace-init/hyprspace-init`.

### Step registry

All installable steps are declared in `libexec/hyprspace-init/step-metadata.sh`. This is the single source of truth for step keys, labels, defaults, and app choices.

Two categories:

| Category | Keys | Behaviour |
|----------|------|-----------|
| Mandatory | `hyprspace_config`, `hack_nerd_font` | Always applied, not shown in the TUI |
| Optional | `sketchybar`, `borders`, `macos_defaults`, `wallpaper` | Shown in the TUI, all selected by default |

App choice menus (terminal, music, browser) are also declared in `step-metadata.sh` with `*_app_choices()` and `default_*_app()` functions.

### Execution flow

```
hyprspace init (TUI)
  └── run_interactive_selection()          # gum choose menus
        └── apply_selection()
              └── apply-init-selections.sh  # dispatches by flag
                    ├── scripts/internal/setup-dependencies.sh    # brew installs
                    ├── scripts/internal/setup-hyprspace-config.sh
                    ├── scripts/internal/setup-sketchybar-config.sh  (if enabled)
                    ├── scripts/internal/setup-macos-defaults.sh     (if enabled)
                    └── scripts/internal/setup-wallpaper.sh          (if enabled)
```

After apply, `complete_setup()` launches Hyprspace.app and runs `sketchybar --reload`.

Non-interactive mode: `HYPRSPACE_INIT_ASSUME_DEFAULTS=1` skips the TUI and applies all defaults.

### Dependency installer (`setup-dependencies.sh`)

Installs packages via Homebrew based on the selected steps and app choices:

| Condition | Package |
|-----------|---------|
| Always | `font-hack-nerd-font` (cask) |
| `sketchybar` or `borders` selected | `FelixKratz/formulae` tap |
| `sketchybar` selected | `sketchybar` (formula) |
| `borders` selected | `borders` (formula) |
| Terminal = Ghostty | `ghostty` (cask) |
| Music = Spotify | `spotify` (cask) |
| Browser = Helium | `helium-browser` (cask) |

All installs are idempotent: already-installed packages are skipped.

### Adding a new optional step

1. Add the key to `OPTIONAL_STEP_KEYS` in `libexec/hyprspace-init/step-metadata.sh`.
2. Add `step_label()` and `step_key_for_label()` cases for the new key.
3. Add a `--with-<key>` / `--without-<key>` flag pair in `apply-init-selections.sh`.
4. Add the corresponding `if [ "$enable_<key>" = "1" ]` block in `apply-init-selections.sh` that calls the setup script.
5. Write `scripts/internal/setup-<key>.sh` for the actual install/config logic.
6. If the step needs Homebrew packages, add them to `setup-dependencies.sh`.
7. Add a `--without-<key>` case to `libexec/hyprspace-deinit/apply-deinit-selections.sh` and the corresponding cleanup script.

### Adding a new app choice

1. Add `<name>_app_choices()` and `default_<name>_app()` functions to `step-metadata.sh`.
2. Add a `validate_<name>_app()` function to `step-metadata.sh`.
3. Thread the choice through `apply-init-selections.sh` as `HYPRSPACE_SELECTED_<NAME>_APP`.
4. Add the conditional brew install in `setup-dependencies.sh`.
5. Use `$selected_<name>_app` in the relevant setup script (e.g., `setup-hyprspace-config.sh`).

### Native helpers

Three Swift helpers are compiled during `install-local` (or release build) by `scripts/internal/build-init-helpers.sh`:

| Helper | Source | Purpose |
|--------|--------|---------|
| `hyprspace-notify-menubar` | `libexec/hyprspace-init/hyprspace-notify-menubar.swift` | Menu bar notification |
| `hyprspace-set-wallpaper` | `libexec/hyprspace-init/hyprspace-set-wallpaper.swift` | Set desktop wallpaper |
| `hyprspace-get-wallpaper` | `libexec/hyprspace-init/hyprspace-get-wallpaper.swift` | Read current wallpaper path |

They are built as universal binaries (arm64 + x86_64) targeting macOS 15.0. Sources live alongside the shell scripts in `libexec/hyprspace-init/`; binaries are never committed.

### Artifacts

| Path | Purpose |
|------|---------|
| `artifacts/configs/hyprspace-config.toml` | Starter config template (rendered into `~/.config/hyprspace/config.toml`) |
| `artifacts/configs/sketchybar/` | Sketchybar plugins and helpers copied to `~/.config/sketchybar/` |
| `artifacts/docs/` | User-facing docs shipped to public release surfaces |

The starter config template is processed by `setup-hyprspace-config.sh`, which substitutes `STARTER_ENABLE_*` and `STARTER_SELECTED_*` variables before writing to disk.

### Deinit flow

`hyprspace deinit` mirrors init. Entry: `libexec/hyprspace-deinit/hyprspace-deinit`. Step registry: `libexec/hyprspace-deinit/step-metadata.sh`. The deinit step keys cover: `sketchybar`, `borders`, `hyprspace_config`, `wallpaper`, `macos_defaults`, `homebrew_tap`.

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
