# Hyprspace Configuration

This directory contains documentation for the installed Hyprspace config.

- When installed, `~/.config/hyprspace/config.toml` in the parent directory is the active config Hyprspace loads
- `docs/default-config.toml` is the installed reference file you can copy settings from
- `docs/ACKNOWLEDGMENTS.md` lists third-party credits

Hyprspace prefers the canonical config path:

```bash
~/.config/hyprspace/config.toml
```

The bundled starter config is intentionally small and opinionated. It gives you a working out-of-the-box setup, while `default-config.toml` is the fuller reference surface installed into `docs/default-config.toml`.

After changing `config.toml`, reload with:

```bash
hyprspace reload-config
```
