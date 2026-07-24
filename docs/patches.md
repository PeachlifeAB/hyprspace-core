# Hyprspace Patches

> GENERATED FILE. Edit patch metadata in `patches/hyprspace/*.patch` and rerun `scripts/internal/generate-patches-doc.py`.

The active stack is the ordered list in `patches/series`. Each patch should provide leading `# Summary: ...` metadata, followed by a plain diff that begins at `diff --git ...`.

## Active patch stack

- `hyprspace/cli-identity-and-root-hash.patch`
  **cli identity and root hash** — Renames the CLI usage text, version output, and shared app metadata from AeroSpace to Hyprspace.

- `hyprspace/runtime-identity-separation.patch`
  **runtime identity separation** — Separates runtime app identity, socket surfaces, and related temp-path behavior from upstream AeroSpace naming.

- `hyprspace/install-surface-identity.patch`
  **install surface identity** — Renames the install and release surfaces to Hyprspace: pkg product, app bundle names, shell completions, Homebrew casks, and release artifacts.

- `hyprspace/fix-grep-ansi-in-generate.patch`
  **fix grep ansi in generate** — Strip ANSI color escapes from grep output in generate.sh so subcommand descriptions render without escape sequences.

- `hyprspace/local-release-build-proof.patch`
  **local release build proof** — fix: remove hyprspace plist in cleanupPlistFromPrevVersions

- `hyprspace/helium-style-versioning.patch`
  **helium style versioning** — Pins generated version files to Hyprspace-controlled values while still exposing the AeroSpace base version.

- `hyprspace/app-menu-command.patch`
  **app menu command** — Adds the app-menu command so Hyprspace can activate a running app and inspect or click menu items through Accessibility APIs.

- `hyprspace/new-window-or-open.patch`
  **new window or open** — Adds new-window-or-open, which opens an app if it is closed and triggers its menu-bar “New Window” action if it is already running.

- `hyprspace/dwindle-layout.patch`
  **dwindle layout** — Implements a Hyprland-style dwindle insertion strategy based on the most recently used tiled window.

- `hyprspace/default-config-alt-b.patch`
  **default config alt b** — Changes the starter browser shortcut so alt-b opens or creates Safari instead of switching to workspace B.

- `hyprspace/position-center.patch`
  **position center** — Adds a position center command that floats the target window and centers it at a large preset size.

- `hyprspace/new-window-or-open-position-preset.patch`
  **new window or open position preset** — Extends new-window-or-open with a trailing position <preset> action and preserves the caller's current workspace for the running-app path.

- `hyprspace/build-script-java-and-generated-restore.patch`
  **build script java and generated restore** — Makes the stripped build environment recover Homebrew OpenJDK automatically when java is missing from the agent shell PATH.

- `hyprspace/position-presets.patch`
  **position presets** — Expands the floating placement behavior with topLeftCorner, topRightCorner, and bottomPanel presets.

- `hyprspace/support-config-toml-filename.patch`
  **support config toml filename** — Supports ~/.config/hyprspace/config.toml as a valid config filename and completes the extra position preset parser cases.

- `hyprspace/canonical-config-paths.patch`
  **canonical config paths** — Makes ~/.config/hyprspace/config.toml the canonical active config and keeps compatibility paths as fallbacks only.

- `hyprspace/opinionated-config-defaults.patch`
  **opinionated config defaults** — Adds Hyprspace built-in defaults and turns the starter config into the opinionated first-run setup.

- `hyprspace/accessibility-status.patch`
  **accessibility status** — Add non-prompting --accessibility-status self-checks for app and CLI

- `hyprspace/open-terminal.patch`
  **open terminal** — Adds open-terminal command, which opens Ghostty or Terminal.app running a specified command via AppleScript; --new forces a fresh app instance.

- `hyprspace/single-window-gaps.patch`
  **single window gaps** — Adds an optional [single-window-gaps] config table used when a workspace has exactly one tiled window, letting a solo window use reduced (or zero) gaps to fill the screen. Reuses the full Gaps grammar including per-monitor arrays.

## Patch files not currently in `patches/series`

- `hyprspace/build-release-restore-generated-files.patch`
  **build release restore generated files** — Restores generated files after release builds without checking them out from the upstream git base.

- `hyprspace/local-install-execution.patch`
  **local install execution** — Adds local-prefix install support and Hyprspace-named release install targets in install-from-sources.sh.

## Upstream-fix bucket

- `patches/upstream-fixes/` is currently empty.

