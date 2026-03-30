#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
checkout_dir="$root_dir/AeroSpace"
log_dir="$root_dir/log/tests"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_file="$log_dir/${timestamp}-hyprspace-install-surface.log"

mkdir -p "$log_dir"
exec > >(tee "$log_file") 2>&1

echo "[info] root_dir=$root_dir"
echo "[info] checkout_dir=$checkout_dir"
echo "[info] log_file=$log_file"

if [[ ! -d "$checkout_dir" ]]; then
    echo "[prereq] patched AeroSpace checkout not found at $checkout_dir"
    echo "[prereq] Run ./scripts/patch/refresh-workspace.sh first."
    exit 1
fi

cd "$checkout_dir"

echo "[step] generating shell completions"
./build-shell-completion.sh

echo "[step] asserting hyprspace completion names"
test -f .shell-completion/zsh/_hyprspace
test -f .shell-completion/fish/hyprspace.fish
test -f .shell-completion/bash/hyprspace

echo "[step] asserting release/install scripts target hyprspace names"
grep -q 'internal implementation detail' build-release.sh
grep -q 'scripts/release/publish-hyprspace-release.sh' build-release.sh
grep -q 'scripts/install/install-local.sh' build-release.sh
test -x script/internal/build-release.sh
grep -q 'product hyprspace' script/internal/build-release.sh
grep -q 'Hyprspace.app' script/internal/build-release.sh
grep -q 'hyprspace' script/internal/build-release.sh
grep -q 'Contents/Resources/libexec/hyprspace-init' script/internal/build-release.sh
grep -q 'build-init-helpers.sh' script/internal/build-release.sh
grep -q 'cp -r "$root_dir/artifacts" .release/artifacts' script/internal/build-release.sh
grep -q 'artifacts/docs/hyprspace-releases-README.md' script/internal/build-release.sh
grep -q 'artifacts/docs/bundled-legal-README.md' script/internal/build-release.sh
grep -q '\$root_dir/LICENSE' script/internal/build-release.sh
grep -q 'homepage "https://hyprspace.net/"' script/build-brew-cask.sh
grep -q 'url "\$zip_uri",' script/build-brew-cask.sh
grep -q 'verified: "github.com/PeachlifeAB/hyprspace-releases/"' script/build-brew-cask.sh
grep -q 'depends_on macos: ">= :sequoia"' script/build-brew-cask.sh
grep -q 'depends_on formula: "gum"' script/build-brew-cask.sh
grep -q "Run 'hyprspace init' to start the setup wizard\." script/build-brew-cask.sh
grep -q 'Hyprspace\.app was installed to /Applications\.' script/build-brew-cask.sh
grep -q 'libexec/hyprspace-init' install-from-sources.sh
grep -q '.release/artifacts' install-from-sources.sh
grep -q 'libexec/hyprspace-init' "$root_dir/scripts/install/install-local.sh"
grep -q 'Hyprspace' "$root_dir/scripts/install/install-local.sh"
grep -q 'setup-dependencies.sh' "$root_dir/scripts/install/install-local.sh"
grep -q 'setup-hyprspace-config.sh' "$root_dir/scripts/install/install-local.sh"
grep -q 'setup-sketchybar-config.sh' "$root_dir/scripts/install/install-local.sh"
grep -q 'setup-macos-defaults.sh' "$root_dir/scripts/install/install-local.sh"
grep -q 'setup-wallpaper.sh' "$root_dir/scripts/install/install-local.sh"
grep -q 'build-init-helpers.sh' "$root_dir/scripts/install/install-local.sh"

echo "[ok] hyprspace install surface test passed"
