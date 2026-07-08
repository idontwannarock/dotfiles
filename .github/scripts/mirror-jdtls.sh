#!/usr/bin/env bash
# Mirror jdtls (Eclipse JDT Language Server). No layout normalization needed — the
# tarball extracts flat and chezmoi handles .tar.gz. The point of mirroring is
# durability: Eclipse prunes old snapshot builds, so a pinned URL eventually 404s.
# Re-hosting the tarball verbatim in our own Releases makes the pin permanent.
#
# Version lives in the filename listed by snapshots/latest.txt (same source scoop
# scrapes), e.g. jdt-language-server-1.61.0-202607061532.tar.gz.
#
# Usage: mirror-jdtls.sh [version]   (no arg = current latest.txt)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
source .github/scripts/mirror-common.sh

base="https://download.eclipse.org/jdtls/snapshots"
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  latest=$(curl -fsSL "$base/latest.txt")
  VERSION=$(printf '%s' "$latest" | sed -E 's/^jdt-language-server-(.+)\.tar\.gz$/\1/')
fi
[ -n "$VERSION" ] || { log "could not parse jdtls version from latest.txt"; exit 1; }
validate_version "$VERSION" || exit 1
log "jdtls target version: ${VERSION}"

file="jdt-language-server-${VERSION}.tar.gz"
url="${base}/${file}"
work=$(mktemp -d)
curl -fsSL -o "$work/$file" "$url"
sha=$(sha256sum "$work/$file" | cut -d' ' -f1)

publish_mirror jdtls "$VERSION" "$url" "$sha" "$work/$file"
[ "${PUBLISH_ONLY:-false}" = "true" ] || open_bump_pr jdtls "$VERSION" jdtlsVersion
