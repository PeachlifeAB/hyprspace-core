#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

git config core.hooksPath .githooks

chmod +x .githooks/pre-commit .githooks/pre-push devutils/preflight.sh
