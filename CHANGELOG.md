# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- Homebrew cask installation via `brew tap PeachlifeAB/hyprspace` and `brew install --cask hyprspace`.
- Versioned GitHub release zip containing the app bundle, CLI, init helpers, configuration docs, legal notices, and bundled support assets for offline inspection.

### Changed

- Canonical public homepage set to `https://hyprspace.net/`.
- Public release artifacts are published in `PeachlifeAB/hyprspace-releases` while the source repository remains private.

### Notes

- Hyprspace releases are currently not code-signed or notarized by Apple. See `artifacts/docs/legal.md` and the public release surfaces for disclosure details.

[0.1.1–0.1.4]: https://github.com/PeachlifeAB/hyprspace-core/compare/v0.1.0...v0.1.4
[0.1.0]: https://github.com/PeachlifeAB/hyprspace-core/releases/tag/v0.1.0
