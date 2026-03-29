# Hyprspace Utils and Test Scripts

Short index of the helper scripts in `devutils/`, `utils/`, and `tests/`. Each entry says what the file is for.

## `devutils/`

Directory role: developer-facing helpers for patch maintenance and local product verification.

- `devutils/install-local.sh`
  Builds and installs a local Hyprspace release.

- `devutils/preflight.sh`
  Runs the fast local enforcement gates before commits or test runs.

- `devutils/validate-patches.sh`
  Validates the full `patches/series` stack against a temporary pinned AeroSpace checkout.

- `devutils/normalize-series-patches.sh`
  Normalizes every in-series patch into the repo-native plain-diff format.

- `devutils/install-githooks.sh`
  Installs the repo-managed git hooks.

### Local developer dependencies for enforcement

These scripts rely on standard local developer tooling plus a patched checkout for the heavier flows.

- `devutils/setup-dependencies.sh`
  Installs the companion dependencies Hyprspace expects for its out-of-box experience.

- `devutils/setup-hyprspace-config.sh`
  Installs the canonical config and docs under `~/.config/hyprspace/`.

- `devutils/setup-sketchybar-config.sh`
  Installs the bundled Sketchybar config bundle.

- `devutils/setup-macos-defaults.sh`
  Applies the recommended macOS defaults.

- `devutils/run-all-tests.sh`
  Runs the default shell-test tier.

## `utils/`

Directory role: helpers that operate on the local `AeroSpace/` checkout and the patch stack.

- `utils/refresh-workspace.sh`
  Rebuilds the ephemeral upstream workspace from patch truth.

## `tests/`

These shell tests are not all equally automation-friendly; GUI/runtime/app-dependent checks require fresh artifacts and TCC approval.

- `tests/_common.sh`
   Shared shell-test helpers.

- `tests/test-hyprspace-app-menu.sh`
   End-to-end check for `app-menu`.

- `tests/test-hyprspace-cli-identity.sh`
   Verifies CLI identity and base version output.

- `tests/test-hyprspace-install-surface.sh`
   Quick install-surface sanity test.

- `tests/test-hyprspace-config-bootstrap.sh`
   Focused bootstrap test for config injection.

- `tests/test-hyprspace-local-install.sh`
   Installs Hyprspace into an isolated local prefix.

- `tests/test-hyprspace-new-window-or-open.sh`
   End-to-end test for `new-window-or-open`.

- `tests/test-hyprspace-new-window-window-count.sh`
   Focused runtime check for new-window creation.

- `tests/test-hyprspace-new-window-workspace-regression.sh`
   Regression repro for the workspace-jump bug.

- `tests/test-hyprspace-real-install.sh`
   Exercises the real local install path.

Tier summary: default fast tier, opt-in integration tier, and opt-in destructive tier.

- `tests/test-hyprspace-release-build.sh`
   Verifies release build output.

- `tests/test-hyprspace-runtime-identity.sh`
   Runs the runtime identity unit guard.

## Generated maintenance docs

- `script/generate-patches-doc.py`
   Regenerates `docs/dev/patches.md` from `patches/series`.
