# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> Current `Hyprspace` patches are based on AeroSpace v0.21.1-Beta

## [Unreleased]

### Added

- `[single-window-gaps]` config table: an optional gaps override applied when a workspace has exactly one tiled window, letting a solo window use reduced (or zero) gaps to fill the screen. Reuses the full `gaps` grammar, including per-monitor arrays. An empty table means zero gaps.

### Changed

- `layout floating` now centers the window on its monitor at 62.5% of the monitor's visible area on each axis, instead of leaving it at whatever frame the tiling layout happened to give it. A window popped out of the tree now lands somewhere usable regardless of where it was tiled. This replaces the previous behavior of restoring the window's last floating size.

## [0.3.0] - 2026-07-06

### Changed

- Rebased Hyprspace patches onto AeroSpace v0.21.1-Beta.
- Adopted AeroSpace v0.21.1 command parsing and exit-code APIs for Hyprspace commands.

### Fixed

- Fresh installs now show a clear "run `hyprspace init` first" gate for server-backed commands when no config exists, while `--help`, `--version`, `--accessibility-status`, and `init` still work before setup.
- Release builds now use Swift 6-compatible accessibility imports.

## [0.2.3] - 2026-06-08

### Added

- Release notes are now extracted from the changelog automatically via a new `extract-release-notes.py` script, replacing the manually maintained `release-notes.md` artifact.

### Fixed

- Homebrew cask deprecation warning: `depends_on macos:` string comparison format replaced with bare symbol syntax (`:sequoia`).

## [0.2.2] - 2026-05-26

### Fixed

- Dwindle layout can now be restored at runtime by toggling workspace windows from floating back to tiling, avoiding a full app restart after manual tree changes such as `move` or `join-with`.
- `move-node-to-workspace` now inserts appended tiled windows through the dwindle insertion path instead of falling back to flat split behavior.

### Changed

- Release automation now has stricter upstream-upgrade safety checks and keeps upstream bump commits local until the final publish push.
- Nightly upstream checks can prepare a reviewable PR when a new AeroSpace release is available.

## [0.2.1] - 2026-05-03

### Fixed

- `open-terminal`: multi-word commands no longer word-split before the shell.
- `open-terminal`: inner shell sources `.zshrc` so interactive env vars are available.
- `open-terminal`: terminal stays open after the command exits.
- `open-terminal Terminal.app`: cold-start no longer opens a duplicate empty window.
- `open-terminal Terminal.app --new`: refuses with a clear error (not supported).

## [0.2.0] - 2026-04-28

### Added

- `open-terminal <app> <command> [--new]` command: opens Ghostty or Terminal.app running a specific command. Uses AppleScript for both backends; `--new` forces a fresh app instance. Login shell is auto-detected via `getpwuid` so PATH loads correctly.
- `btop` as an optional init step (selected by default). The starter config binds `alt-shift-p` to launch btop in the user's chosen terminal.
- `new-window` as a short alias for `new-window-or-open`.

### Changed

- Init flow documentation in `DEVELOPMENT.md` now covers how to update default keybindings and how to add new installable tools.

## [0.1.9] - 2026-04-20

### Added

- Mise task wrappers for the public `scripts/` entry points, so install, patch, release, and verify flows can be launched through `mise run`.

### Fixed

- `hyprspace init` now opens the installed app by direct bundle path and reloads SketchyBar at the end of setup, including the default non-interactive path used after install.
- Init smoke coverage now verifies the post-setup launch and SketchyBar reload sequence without depending on a preinstalled app on the host machine.

### Changed

- Development docs now point to the new mise task names instead of repeating release flow details.

## [0.1.8] - 2026-04-07

### Fixed

- Release pipeline: ANSI color injection from tool runners breaking git output parsing in all release scripts.
- Release pipeline: manifest and publish script referencing stale `brew-README.md` path.
- Pre-release checks now validate manifest source files exist, patch series integrity, and docs freshness.
- Homebrew tap renamed from `PeachlifeAB/brew` to `PeachlifeAB/tap` (standard naming). Legacy `PeachlifeAB/hyprspace` tap mirrored for backward compatibility.

## [0.1.7] - 2026-04-07

### Added

- `hyprspace deinit` interactive teardown wizard for clean uninstall.
- Wallpaper getter helper (`hyprspace-get-wallpaper`).

### Fixed

- ANSI escape handling in generate script.

### Changed

- Documentation updated to reflect open-source status and code-signing.
- Source repository `PeachlifeAB/hyprspace-core` is now public.

## [0.1.6] - 2026-04-01

### Changed

- SketchyBar auto-hide now uses `--bar hidden` instead of toggling item drawing, fixing hide behavior.
- Cursor proximity is now tracked against whichever screen the cursor is on, enabling correct multi-monitor behavior with SketchyBar.
- Auto-hide thresholds and poll rate tuned for snappier response.

## [0.1.5] - 2026-03-31

### Added

- More default key bindings in the initial setup flow.

### Changed

- `hyprspace init` now uses bundled compiled helper binaries for menu-bar notification and wallpaper setup.
- Homebrew installation now declares `gum` as a dependency for the interactive init flow.

## [0.1.1–0.1.4] - 2026-03-30

### Added

- Release codesigning for the packaged app and shipped runtime binaries.
- Dedicated publish prechecks to fail early before expensive release work.

### Changed

- Release packaging, runtime paths, and install surface layout were tightened and cleaned up.
- The publish flow now enforces a matching `CHANGELOG.md` version entry before release.

### Fixed

- Binary path handling and release logging during packaging.
- Install-surface patch consistency and file-structure issues across the packaged runtime.

## [0.1.0] - 2026-03-26

### Added

- First public Hyprspace release.
- Homebrew cask installation via `brew tap PeachlifeAB/tap` and `brew install --cask hyprspace`.
- Versioned GitHub release zip containing the app bundle, CLI, init helpers, configuration docs, legal notices, and bundled support assets for offline inspection.

### Changed

- Canonical public homepage set to `https://hyprspace.net/`.
- Public release artifacts are published in `PeachlifeAB/hyprspace-releases` and the source repository is open at `PeachlifeAB/hyprspace-core`.

### Notes

- Release codesigning was added in 0.1.1–0.1.4. See `artifacts/docs/legal.md` and the public release surfaces for disclosure details.

[0.2.1]: https://github.com/PeachlifeAB/hyprspace-core/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/PeachlifeAB/hyprspace-core/compare/v0.1.9...v0.2.0
[0.1.9]: https://github.com/PeachlifeAB/hyprspace-core/compare/v0.1.8...v0.1.9
[0.1.8]: https://github.com/PeachlifeAB/hyprspace-core/compare/v0.1.7...v0.1.8
[0.1.7]: https://github.com/PeachlifeAB/hyprspace-core/compare/v0.1.6...v0.1.7
[0.1.1–0.1.4]: https://github.com/PeachlifeAB/hyprspace-core/compare/v0.1.0...v0.1.4
[0.1.0]: https://github.com/PeachlifeAB/hyprspace-core/releases/tag/v0.1.0
[0.3.0]: https://github.com/PeachlifeAB/hyprspace-core/compare/v0.2.3...v0.3.0
[0.2.3]: https://github.com/PeachlifeAB/hyprspace-core/compare/v0.2.2...v0.2.3
