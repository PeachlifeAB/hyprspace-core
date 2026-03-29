# Configuring Hyprspace

Hyprspace uses an active config and an installed reference config under `~/.config/hyprspace/`:

- `config.toml` — the active config Hyprspace actually loads
- `docs/default-config.toml` — the installed reference file you can copy settings from

## Which file matters?

The important one is:

```bash
~/.config/hyprspace/config.toml
```

That is the config Hyprspace reads at runtime.

`docs/default-config.toml` is not loaded automatically. It exists to show the broader option surface and give you example values to copy into your own `config.toml`.

## First-run workflow

A minimal first-run setup is:

> **Create/edit config.toml (first-time setup or manual edit).** Skip this step if the installer or `hyprspace init` already created your config.

```bash
mkdir -p ~/.config/hyprspace
open -a TextEdit ~/.config/hyprspace/config.toml
```

After installation or bootstrap, Hyprspace expects these files to exist:

```bash
~/.config/hyprspace/config.toml
~/.config/hyprspace/docs/default-config.toml
~/.config/hyprspace/README.md
```

## Editing the config

Open `config.toml` in your editor and change the bindings or settings you care about.
For example:

```toml
[mode.main.binding]
alt-enter = 'exec-and-forget open -a Alacritty'
```

After changing the file, reload with:

```bash
hyprspace reload-config
```

## Where to find the full option surface

Hyprspace intentionally keeps the starter config small.
For the broader command and config surface, use:

- the local `docs/default-config.toml` reference file
- the upstream AeroSpace guide: https://nikitabobko.github.io/AeroSpace/guide
- the upstream AeroSpace commands reference: https://nikitabobko.github.io/AeroSpace/commands

## Internal notes

If you are modifying config resolution behavior in the codebase itself, see `../DEVELOPMENT.md`.