# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.8]: https://github.com/PeachlifeAB/hyprspace-core/compare/v0.1.7...v0.1.8
[0.1.7]: https://github.com/PeachlifeAB/hyprspace-core/compare/v0.1.6...v0.1.7
[0.1.1–0.1.4]: https://github.com/PeachlifeAB/hyprspace-core/compare/v0.1.0...v0.1.4
[0.1.0]: https://github.com/PeachlifeAB/hyprspace-core/releases/tag/v0.1.0
