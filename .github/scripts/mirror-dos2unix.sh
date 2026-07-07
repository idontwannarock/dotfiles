#!/usr/bin/env bash
# Mirror dos2unix. Upstream is a single personal site (waterlander.net) with an
# HTML "Stable version: X.Y.Z" line and no Renovate datasource — the same source
# scoop's checkver scrapes. We extract just dos2unix.exe (the only binary this repo
# uses; it runs with no DLLs) and re-host it at a stable URL under our own Releases.
#
# Usage: mirror-dos2unix.sh [version]   (no arg = scrape the homepage)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
source .github/scripts/mirror-common.sh

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  page=$(curl -fsSL "https://waterlander.net/dos2unix/")
  VERSION=$(printf '%s' "$page" | grep -oiE 'Stable version:[[:space:]]+[0-9.]+' | grep -oE '[0-9.]+' | head -n1)
fi
[ -n "$VERSION" ] || { log "could not scrape dos2unix version"; exit 1; }
log "dos2unix target version: ${VERSION}"

url="https://waterlander.net/dos2unix/files/dos2unix-${VERSION}-win64.zip"
work=$(mktemp -d)
curl -fsSL -o "$work/dos2unix.zip" "$url"
sha=$(sha256sum "$work/dos2unix.zip" | cut -d' ' -f1)

unzip -qo "$work/dos2unix.zip" "bin/dos2unix.exe" -d "$work"
asset="$work/dos2unix-${VERSION}.exe"
mv "$work/bin/dos2unix.exe" "$asset"

publish_mirror dos2unix "$VERSION" "$url" "$sha" "$asset"
[ "${PUBLISH_ONLY:-false}" = "true" ] || open_bump_pr dos2unix "$VERSION" dos2unixVersion
