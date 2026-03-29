# Hyprspace Legal and Public Release Disclosure

## Fork Attribution

Hyprspace is a fork of [AeroSpace](https://github.com/nikitabobko/AeroSpace) by Nikita Bobko, licensed under the MIT License. The upstream AeroSpace source is the base on which Hyprspace patches are applied. See `LICENSE` at the repo root for the full combined Hyprspace public copyright and license text.

The same public license text is bundled in every Hyprspace release artifact at `legal/LICENSE.txt`.

The source and patch-control repository is private at `PeachlifeAB/hyprspace-core`. Public release artifacts are published separately to `PeachlifeAB/hyprspace-releases`, and the public Homebrew tap lives at `PeachlifeAB/homebrew-hyprspace`.

## Third-Party Dependencies

Hyprspace bundles the same third-party dependencies as AeroSpace. The full inventory and individual licenses are bundled in every release artifact under `legal/third-party-license/`. A summary follows:

| Dependency | License | Usage |
|------------|---------|-------|
| [HotKey](https://github.com/soffes/HotKey) | MIT | Global keyboard shortcut handling (macOS Carbon API wrapper) |
| [TOMLKit](https://github.com/LebJe/TOMLKit) | MIT | Swift wrapper for TOML config parsing |
| [tomlplusplus](https://github.com/marzer/tomlplusplus) | MIT | Underlying TOML C++ parser (used via TOMLKit) |
| [ANTLR v4](https://github.com/antlr/antlr4) | BSD-3-Clause | Parses AeroSpace built-in shell-like language |
| [swift-collections](https://github.com/apple/swift-collections) | Apache 2.0 | Advanced Swift collection types |
| [ISSoundAdditions](https://github.com/InerziaSoft/ISSoundAdditions) | MIT | System volume control API |

Full license texts for each dependency are available in `legal/third-party-license/` inside the release zip.

## Code Signing and Notarization

**Hyprspace releases are currently not code-signed or notarized by Apple.**

When installing via Homebrew cask, the postflight step removes the macOS quarantine attribute (`com.apple.quarantine`) from the app bundle and CLI binary so they can run without Gatekeeper prompting. Users who prefer to verify the binary manually can inspect the release zip SHA256 checksum published alongside each GitHub release.

This status will be updated in these docs if notarization is added in a future release.

## Release Artifact Contents

Each Hyprspace release zip (`Hyprspace-vMAJOR.MINOR.PATCH.zip`) contains:

- `README.md` — public release landing page for offline readers
- `Hyprspace.app/` — macOS application bundle
- `bin/hyprspace` — CLI binary
- `shell-completion/` — zsh, bash, and fish completions
- `libexec/hyprspace-init/` — first-run initialization runtime
- `manpage/` — man pages (if built with docs enabled)
- `legal/README.md` — bundled legal payload guide
- `legal/LICENSE.txt` — bundled public Hyprspace license text
- `legal/third-party-license/` — bundled third-party license texts
- `docs/` — config and legal disclosure docs
- `configs/` — default sketchybar and AeroSpace config examples
- `gfx/` — bundled wallpaper and release-managed icon source assets
- `devutils/` — optional setup helpers (dependency install, macOS defaults, sketchybar config)
