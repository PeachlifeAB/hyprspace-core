# Hyprspace Public Legal Disclosure

## Fork Attribution

Hyprspace is a fork of AeroSpace by Nikita Bobko and remains based on upstream AeroSpace source plus Hyprspace patches. The combined Hyprspace public license text is published in this repository as `LICENSE`, and each release zip also bundles `legal/LICENSE.txt`.

The Hyprspace source and patch-control repository is private at `PeachlifeAB/hyprspace-core`. Public release artifacts are published in `PeachlifeAB/hyprspace-releases`, and the public Homebrew tap lives in `PeachlifeAB/homebrew-hyprspace`.

## Third-Party Dependencies

Hyprspace bundles the same third-party dependencies as AeroSpace. Each published release zip includes `legal/third-party-license/` with the bundled dependency license texts. A summary is maintained in the private-source `docs/legal.md` and mirrored in release artifacts for offline reading.

## Code Signing and Notarization

Hyprspace releases are currently not code-signed or notarized by Apple.

When installed via the public Homebrew cask, the cask postflight removes the macOS quarantine attribute from the staged CLI binary and installed app bundle. Users who prefer to verify the release artifact directly can compare the downloaded zip against the published Homebrew cask SHA256 and GitHub release asset.

## Public Surfaces

External users and auditors can inspect the following public surfaces without access to the private source repository:

- `README.md` in this repository for public install and manual-download guidance
- `LEGAL.md` in this repository for public disclosure
- `LICENSE` in this repository for the Hyprspace public license text
- The GitHub release page for version-specific notes and the published release zip
- The Homebrew tap README and cask in `PeachlifeAB/homebrew-hyprspace`

## Release Artifact Contents

Each public Hyprspace release zip contains at least the following user-visible/legal surfaces:

- `README.md`
- `docs/legal.md`
- `legal/README.md`
- `legal/LICENSE.txt`
- `legal/third-party-license/`
