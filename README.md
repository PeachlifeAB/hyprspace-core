# Hyprspace

Hyprspace is a tiling window manager for macOS, built as a product fork of [AeroSpace](https://github.com/nikitabobko/AeroSpace). It keeps AeroSpace's core strengths, but adds a more opinionated desktop experience around launcher bindings, focus-driven window placement, and bundled integrations like Sketchybar and JankyBorders.

## Why use Hyprspace

Hyprspace is designed for macOS users who want an out-of-the-box, dynamic tiling window manager experience similar to [Hyprland](https://hyprland.org). While the upstream AeroSpace project is a manual tiling manager that requires you to build your configuration from scratch, Hyprspace delivers a "batteries-included" environment tailored for immediate productivity.

The project is heavily inspired by [Omarchy](https://omarchy.org/), an opinionated, developer-focused Arch Linux distribution built around Hyprland. Hyprspace aims to replicate that cohesive, beautifully customized, keyboard-centric workflow directly on macOS without the setup fatigue.

### Out-of-the-box features:

* **Quick Setup Wizard:** An interactive first-run setup that lets you choose from opinionated application suites for each default keybinding—for example, pick Safari or Helium for `alt-b`, Ghostty or Terminal for `alt-enter`—and optionally toggle bundled integrations like JankyBorders and Sketchybar on or off.
* **Dynamic Dwindle Layout:** Replaces manual window management with an automatic binary tree layout that dynamically splits windows based on the width-to-height ratio of the active container.
* **Opinionated Desktop Integrations:** Comes pre-bundled with [Sketchybar](https://github.com/FelixKratz/SketchyBar) for a Hyprland-inspired menu bar (displaying the focused workspace and system stats) and [JankyBorders](https://github.com/FelixKratz/JankyBorders) for clean window borders.
* **Focus-Driven Window Spawning:** App launch bindings use the `new-window-or-open` command by default, which always opens a new window of the target application directly in your current workspace.
* **Works with SIP Enabled:** Get a full tiling window management experience right out of the box without needing to alter your macOS security settings. Hyprspace works flawlessly with System Integrity Protection (SIP) fully enabled.
* **First-Class Floating Presets:** Includes predictable, named placement presets such as `topRightCorner` and `center`, allowing common utility windows to be positioned seamlessly without external helpers.

## Install

```bash
brew tap PeachlifeAB/tap
brew install --cask hyprspace
```

For legal information, third-party notices, and signing disclosure, see [`artifacts/docs/legal.md`](artifacts/docs/legal.md).

## Configuration

Hyprspace uses:

- **active config:** `~/.config/hyprspace/config.toml`
- **reference config:** `~/.config/hyprspace/docs/default-config.toml`

`config.toml` is the real config Hyprspace loads.
`docs/default-config.toml` is a reference file you can copy settings from.

A minimal first-run workflow is:

```bash
mkdir -p ~/.config/hyprspace
open -a TextEdit ~/.config/hyprspace/config.toml
```

For the user-facing config guide, see [`artifacts/docs/config.md`](artifacts/docs/config.md).

## Product behavior

### Focus-driven window spawning

Hyprspace adds higher-level app window commands like `new-window-or-open`, and its target behavior is focus-driven insertion: repeated app-window spawning should respect the workspace and focus context you are currently in, instead of jumping back to an older workspace just because the app is already running elsewhere.

### Floating placement presets

Hyprspace also adds named floating placement presets so common utility windows can be placed predictably without external helpers. The current preset surface includes center, panel, and corner-style placements through the `position` command and `new-window-or-open ... position <preset>` flow.

## Documentation

### For users
- Config guide: [`artifacts/docs/config.md`](artifacts/docs/config.md)
- Legal and release disclosure: [`artifacts/docs/legal.md`](artifacts/docs/legal.md)

### For contributors and maintainers
- Development guide: [`DEVELOPMENT.md`](DEVELOPMENT.md)
- Patch stack index: [`docs/patches.md`](docs/patches.md)

## Upstream AeroSpace resources

Hyprspace is still built on top of AeroSpace, so upstream command/config documentation remains useful unless a Hyprspace patch explicitly changes the behavior:

- Guide: https://nikitabobko.github.io/AeroSpace/guide
- Commands: https://nikitabobko.github.io/AeroSpace/commands
- Goodies: https://nikitabobko.github.io/AeroSpace/goodies
- Upstream AeroSpace repo: https://github.com/nikitabobko/AeroSpace
