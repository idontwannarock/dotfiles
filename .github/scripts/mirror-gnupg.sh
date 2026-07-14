#!/usr/bin/env bash
# Detect GnuPG for Windows -- checkver-only, NO re-host. Unlike vim/jdtls/dos2unix
# the gnupg.org download URLs are durable, so this job publishes no mirror release:
# it only detects the current version + build date + SHA-256 and opens a 3-variable
# bump PR against home/run_onchange_install-gnupg.ps1.tmpl.
#
# Sources (the same feeds scoop's gpg.json checkver uses):
#   version + date : https://www.gnupg.org/download/index.html
#                    -> the single advertised `gnupg-w32-<ver>_<date>.exe`
#   sha256         : https://www.gnupg.org/download/integrity_check.html
#                    -> the 64-hex line for that exact basename (the page also
#                       lists a 40-hex SHA-1 and other release lines)
#
# Usage: mirror-gnupg.sh   (no args; PUBLISH_ONLY=true -> no-op, nothing to seed)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
source .github/scripts/mirror-common.sh

PIN_FILE="home/run_onchange_install-gnupg.ps1.tmpl"

# Seed mode (workflow_dispatch publish_only=true) exists to create mirror releases
# before the workflow is on main. gnupg has no release to create -> no-op.
if [ "${PUBLISH_ONLY:-false}" = "true" ]; then
  log "gnupg is detect-only (no re-host); nothing to publish in seed mode"
  exit 0
fi

# 1. version + date from the download page. It advertises only the single current
#    Windows installer, so the first match is the target -- no release-line filter.
index=$(curl -fsSL "https://www.gnupg.org/download/index.html")
verdate=$(printf '%s' "$index" | grep -oE 'gnupg-w32-[0-9.]+_[0-9]+\.exe' | head -n1)
[ -n "$verdate" ] || { log "could not scrape gnupg-w32 filename from index.html"; exit 1; }
VERSION=$(printf '%s' "$verdate" | sed -E 's/^gnupg-w32-([0-9.]+)_[0-9]+\.exe$/\1/')
DATE=$(printf '%s' "$verdate" | sed -E 's/^gnupg-w32-[0-9.]+_([0-9]+)\.exe$/\1/')
validate_version "$VERSION" || exit 1
validate_version "$DATE" || exit 1
log "gnupg target: version=${VERSION} date=${DATE}"

# 2. sha256 from the integrity page. Anchor on 64 hex chars so the SHA-256 line is
#    selected over the co-listed 40-hex SHA-1, and on the exact basename so another
#    release line's hash (e.g. the 2.2.x LTS build) can't be picked up.
basename="gnupg-w32-${VERSION}_${DATE}.exe"
basename_re=$(printf '%s' "$basename" | sed 's/\./\\./g')
integ=$(curl -fsSL "https://www.gnupg.org/download/integrity_check.html")
SHA256=$(printf '%s' "$integ" | grep -oE "[0-9a-f]{64}[[:space:]]+${basename_re}" | head -n1 | grep -oE '^[0-9a-f]{64}' || true)
[ -n "$SHA256" ] || { log "could not find sha256 for ${basename} in integrity_check.html"; exit 1; }
printf '%s' "$SHA256" | grep -qE '^[0-9a-f]{64}$' || { log "sha256 for ${basename} malformed: [$SHA256]"; exit 1; }
log "gnupg sha256: ${SHA256}"

# 3. current pin -- $gpgVersion in the install script (mirrors common.sh current_pin,
#    but against PIN_FILE, not .chezmoiexternal.toml).
CUR=$(sed -nE "s/.*\\\$gpgVersion[[:space:]]*:=[[:space:]]*\"([^\"]+)\".*/\1/p" "$PIN_FILE" | head -n1)
if [ -z "$CUR" ]; then
  log "could not read \$gpgVersion from ${PIN_FILE}; skipping PR"
  exit 0
fi
if [ "$CUR" = "$VERSION" ]; then
  log "gnupg pin already at ${VERSION}; no PR"
  exit 0
fi

# 4. bump all three coupled variables in one commit, open one PR. Idempotency keys
#    on an OPEN PR (recover-on-rerun), same rationale as common.sh open_bump_pr.
branch="mirror/gnupg-${VERSION}"
if [ -n "$(gh pr list --head "$branch" --state open --json number --jq '.[0].number' 2>/dev/null)" ]; then
  log "PR for ${branch} already open; skipping"
  exit 0
fi
log "bumping gnupg pin: ${CUR} -> ${VERSION} (date ${DATE})"
git switch -C "$branch"   # -C: reset a branch a prior failed run may have left
# SHA-256 stored uppercase to match the file's existing convention (the install
# script's PowerShell -ne compare is case-insensitive, so bytes are equivalent).
SHA_UP=${SHA256^^}
sed -i -E "s/(\\\$gpgVersion[[:space:]]*:=[[:space:]]*\")[^\"]+(\")/\1${VERSION}\2/" "$PIN_FILE"
sed -i -E "s/(\\\$gpgDate[[:space:]]*:=[[:space:]]*\")[^\"]+(\")/\1${DATE}\2/" "$PIN_FILE"
sed -i -E "s/(\\\$gpgSha256[[:space:]]*:=[[:space:]]*\")[^\"]+(\")/\1${SHA_UP}\2/" "$PIN_FILE"
git -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit -am "chore(deps): bump gnupg ${CUR} -> ${VERSION}"
git push --force origin "$branch"
# Ensure the label exists so `gh pr create --label` can't fail on a missing one.
gh label create dependencies --color 0366d6 --description "Dependency updates" 2>/dev/null || true
gh pr create --label dependencies --base main --head "$branch" \
  --title "chore(deps): bump gnupg ${CUR} -> ${VERSION}" \
  --body "Detected GnuPG for Windows \`${CUR}\` → \`${VERSION}\` (build ${DATE}) from gnupg.org via \`mirror-externals.yml\` (detect-only — no mirror release; gnupg.org URLs are durable).

Updates \`\$gpgVersion\`, \`\$gpgDate\`, and \`\$gpgSha256\` in \`home/run_onchange_install-gnupg.ps1.tmpl\`. SHA-256 \`${SHA256}\` was read from gnupg.org/download/integrity_check.html; the install script re-verifies it against the actual download at \`chezmoi apply\` time.

Squash auto-merge is enabled: this merges once the \`validate-externals\` check passes. Nothing reaches a machine until you run \`chezmoi apply\`."
# Auto-merge once the required validate-externals check is green (GitHub waits for it).
gh pr merge --auto --squash --delete-branch "$branch" 2>/dev/null || true
