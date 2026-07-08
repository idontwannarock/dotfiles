#!/usr/bin/env bash
# Mirror vim (vim/vim-win32-installer) with layout normalization: the upstream zip
# names its runtime dir vimXX by MAJOR.MINOR (vim92, vim93, …), which couples the
# version into the on-disk path and into the 15 .cmd wrappers. We rename it to a
# stable `current/` so the wrappers never change across version bumps.
#
# Usage: mirror-vim.sh [version]   (no arg = latest upstream release)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
source .github/scripts/mirror-common.sh

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  VERSION=$(gh api repos/vim/vim-win32-installer/releases/latest --jq .tag_name | sed 's/^v//')
fi
[ -n "$VERSION" ] || { log "could not resolve vim version"; exit 1; }
validate_version "$VERSION" || exit 1
log "vim target version: ${VERSION}"

url="https://github.com/vim/vim-win32-installer/releases/download/v${VERSION}/gvim_${VERSION}_x64.zip"
work=$(mktemp -d)
curl -fsSL -o "$work/gvim.zip" "$url"
sha=$(sha256sum "$work/gvim.zip" | cut -d' ' -f1)

unzip -q "$work/gvim.zip" -d "$work/extracted"
# upstream layout: extracted/vim/vim<XX>/…  -> rename vim<XX> to `current`
runtime=$(find "$work/extracted" -maxdepth 2 -type d -name 'vim[0-9]*' | head -n1)
[ -n "$runtime" ] || { log "could not find vimXX runtime dir in the upstream zip"; exit 1; }
mkdir -p "$work/stage"
mv "$runtime" "$work/stage/current"

asset="$work/mirror-vim-${VERSION}.zip"
( cd "$work/stage" && zip -qr "$asset" current )

publish_mirror vim "$VERSION" "$url" "$sha" "$asset"
[ "${PUBLISH_ONLY:-false}" = "true" ] || open_bump_pr vim "$VERSION" vimVersion
