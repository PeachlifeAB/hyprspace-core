#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root_dir"

source ./product.conf
source ./scripts/release/release-lib.sh

current="$(read_aerospace_version "$root_dir")"
latest="$(latest_aerospace_tag)"

if [ -z "$latest" ]; then
    die "could not determine latest AeroSpace tag"
fi

if [ "$latest" = "$current" ]; then
    echo "AeroSpace is already current: $current"
    exit 0
fi

echo "Preparing AeroSpace upgrade: $current -> $latest"
echo "$latest" >aerospace_version.txt

mise run patch:refresh-workspace
mise run patch:validate
