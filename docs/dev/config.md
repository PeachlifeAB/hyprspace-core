# Hyprspace Config Resolution Internals

This document is for contributors working on Hyprspace config path resolution and startup config behavior.

## Config search order

Hyprspace searches for a custom config in the following order:

1. `~/.config/hyprspace/config.toml`
2. `~/.hyprspace.toml`
3. `~/Library/Application Support/Hyprspace/config.toml`

The canonical `~/.config/hyprspace/config.toml` path wins when it exists.
Compatibility paths are only read when the canonical path is missing.

## Starter and reference configs

If no custom config is found, Hyprspace falls back to its embedded starter config.

Key facts:
- the maintainer-owned starter config template lives at `configs/hyprspace-config.toml` in the repo root
- the starter config is intentionally small and opinionated
- `~/.config/hyprspace/docs/default-config.toml` is the installed reference file and is never treated as a live config candidate
- when a custom config is found, the embedded starter config is ignored rather than merged

## Code locations

Relevant implementation files:
- `AeroSpace/Sources/AppBundle/config/ConfigFile.swift`
- `AeroSpace/Sources/AppBundle/config/parseConfig.swift`

## User-facing docs

For end-user config guidance, see `docs/config.md`.
