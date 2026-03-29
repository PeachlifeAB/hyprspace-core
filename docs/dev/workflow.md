# Hyprspace Development Workflow

This document is for contributors and maintainers working on the Hyprspace codebase itself.

## Repo structure

The script-owned truth for this workflow lives in `patches/series`, `utils/refresh-workspace.sh`, `devutils/`, and the test scripts.

## Refreshing the workspace

To reconstruct the current Hyprspace product tree from patch truth, run:

```bash
./utils/refresh-workspace.sh
```

See `utils/refresh-workspace.sh` for the exact rebuild behavior. It only updates patched source files, not release artifacts.

## Building and installing locally

Use the local product path, not the upstream Homebrew installer:

```bash
./devutils/install-local.sh
```

See `devutils/install-local.sh` for the full local install sequence.

## Verification preflight before heavy runs

Before a long build, install, or end-to-end test, follow the repo-state and script-check routine:

The underlying proof surface is the script output, the test assertions, and the repo-state log.

Never run two build/install/test commands in parallel against the same `AeroSpace/` checkout.

### Runtime surfaces and Accessibility (TCC)

When testing window manager behavior, be aware that the globally installed app (`/Applications/Hyprspace.app`) and a workspace-built app (e.g. `AeroSpace/.xcode-build/.../Hyprspace.app`) are distinct runtime surfaces. They have separate Accessibility (TCC) permissions in macOS System Settings.

Always state exactly which app path you are testing to avoid TCC confusion. Missing Accessibility approval for the exact runtime surface under test is a hard show-stopper for runtime and manual validation.

## Patch ownership workflow

Before editing anything inside `AeroSpace/`:

1. Read `patches/series`.
2. Read the patch file or files that already own the behavior you are about to change.
3. Decide whether you are:
   - updating one existing patch
   - adding a new patch
   - updating multiple existing patches
   - updating one patch and adding one new patch

Default rule: **same behavior = same patch**.

## Updating an existing patch

Typical flow:

```bash
./utils/refresh-workspace.sh
# edit files inside AeroSpace/
# verify with ./devutils/install-local.sh and focused tests
bash ./devutils/regenerate-patch.sh <existing-patch-name>
./utils/refresh-workspace.sh
```

`devutils/regenerate-patch.sh` is the default replace-an-existing-patch path. It resolves the patch from `patches/series`, reconstructs the pre-target base in temporary trees, rejects unrelated live `AeroSpace/` edits unless you explicitly allow a new owned path with `--add-file`, and rewrites the same patch file as a plain diff while preserving leading `# Summary: ...` metadata.

Do not append to `patches/series` when replacing an existing patch file; use `devutils/regenerate-patch.sh`.

## Release-related docs

- Source install: `docs/installing-from-source.md`
- Maintainer release runbook: `docs/maintainer-release.md`
- Patch stack index: `docs/dev/patches.md`
- Utils/tests index: `docs/dev/utils.md`
- Config behavior: `docs/dev/config.md`
