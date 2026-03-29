# Homebrew Cask Cheatsheet

Use this as a tiny maintainer reference for proven cask patterns.

## Public cask shape

```ruby
cask "hyprspace" do
  version "0.1.0"
  sha256 "..."

  url "https://github.com/PeachlifeAB/hyprspace-releases/releases/download/v#{version}/Hyprspace-v#{version}.zip",
      verified: "github.com/PeachlifeAB/hyprspace-releases/"
  name "Hyprspace"
  desc "Tiling window manager based on AeroSpace"
  homepage "https://hyprspace.net/"

  depends_on macos: ">= :sequoia"

  app "Hyprspace-v#{version}/Hyprspace.app"
  binary "Hyprspace-v#{version}/bin/hyprspace"
end
```

## Proven patterns

- `verified:` belongs on the `url` stanza when the download host differs from `homepage`. Source: Homebrew Cask Cookbook, plus upstream casks like `wezterm`, `rustdesk`, and `whisky`.
- Audit local casks by **name**, not by file path. `brew audit [path ...]` is disabled in modern Homebrew.
- Local `file://` rehearsal casks should omit `verified:`. Homebrew audit skips the verified check for `file://` URLs.
- Use `depends_on macos: ">= :sequoia"` style for a minimum macOS floor.
- Use `app` for the bundle and `binary` for CLI/shell-completion links from inside the staged archive.
- Keep `caveats` only for install-time user guidance.

## Minimal validation

```bash
brew style Casks/hyprspace.rb
brew audit --cask --online hyprspace
HOMEBREW_NO_INSTALL_FROM_API=1 brew install --cask hyprspace
brew uninstall --cask hyprspace
```

## Sources

- https://docs.brew.sh/Cask-Cookbook#stanza-url
- https://docs.brew.sh/Cask-Cookbook#when-url-and-homepage-domains-differ-add-verified
- `refcode/homebrew-cask/Casks/w/wezterm.rb`
- `refcode/homebrew-cask/Casks/r/rustdesk.rb`
- `refcode/homebrew-cask/Casks/w/whisky.rb`
- `Homebrew/brew` audit logic: `audit_missing_verified` returns early for `file://` URLs