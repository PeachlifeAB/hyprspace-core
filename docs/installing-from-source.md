# Installing Hyprspace for Development

This document details the exact process for compiling and installing Hyprspace during local development. It avoids brittle upstream (AeroSpace) Homebrew-based installer logic, offering a fully independent and safe workflow.

## What this path does

Local development installs use a deterministic script instead of the upstream Homebrew-based install path. The full sequence lives in `devutils/install-local.sh`, which handles build, install, bootstrap, and launch.

## Execution

Whenever you test a new patch or native algorithm (like the Dwindle layout), run:

```bash
chmod +x devutils/install-local.sh
./devutils/install-local.sh
```

See the script for exact PATH and install-surface requirements.

## Runtime Validation and Accessibility (TCC)

Because this install path is not notarized, the app requires manual Gatekeeper and Accessibility approval to function as a window manager.

1. **Missing Accessibility approval is a hard show-stopper** for runtime and manual validation. The app will not manage windows without it.
2. **User presence cannot be assumed.** Any automated or agent-driven validation must stop after launching the app and wait for the user to explicitly confirm they have granted TCC permissions.
3. **Watch out for duplicate TCC entries.** A workspace-built app (`AeroSpace/.xcode-build/.../Hyprspace.app`) and the globally installed app (`/Applications/Hyprspace.app`) are distinct runtime surfaces. They have separate Accessibility entries in System Settings. Always verify you are granting permission to the exact path you intend to run.
