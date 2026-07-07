#!/usr/bin/env bash
# Shared helpers for the mirror-externals jobs (see .github/workflows/mirror-externals.yml).
#
# Each mirror-<tool>.sh sources this file, produces its normalized asset(s), then
# calls:
#   publish_mirror <tool> <version> <upstream_url> <upstream_sha256> <asset...>
#   open_bump_pr   <tool> <version> <externals-var-name>      (skipped when PUBLISH_ONLY=true)
#
# The two-step split is deliberate: publish first so the mirror URL exists, then
# bump the pin so the new URL is always valid. Both steps are idempotent.
set -euo pipefail

EXTERNALS="home/.chezmoiexternal.toml"

log() { printf '>> %s\n' "$*" >&2; }

# current_pin <var> -> the version currently pinned for `{{- $<var> := "…" }}`.
current_pin() {
  local var="$1"
  sed -nE "s/.*\\\$${var}[[:space:]]*:=[[:space:]]*\"([^\"]+)\".*/\1/p" "$EXTERNALS" | head -n1
}

# release_exists <tag>
release_exists() { gh release view "$1" >/dev/null 2>&1; }

# publish_mirror <tool> <version> <upstream_url> <upstream_sha256> <asset_file...>
# Creates release `mirror-<tool>-<version>` with provenance notes, unless it exists.
publish_mirror() {
  local tool="$1" version="$2" upstream_url="$3" sha="$4"; shift 4
  local tag="mirror-${tool}-${version}"
  if release_exists "$tag"; then
    log "release ${tag} already exists; skipping publish"
    return 0
  fi
  local notes
  notes=$(cat <<EOF
Mirror of **${tool} ${version}**, repackaged for chezmoi by \`.github/workflows/mirror-externals.yml\`.

- Upstream: ${upstream_url}
- Upstream version: ${version}
- Upstream file sha256: \`${sha}\`

The repackaged asset's bytes differ from the upstream file; verify provenance against the sha256 above.
EOF
)
  log "creating release ${tag}"
  gh release create "$tag" "$@" --title "$tag" --notes "$notes"
}

# open_bump_pr <tool> <version> <externals-var-name>
# Opens a one-line pin-bump PR when the pin differs from <version>. Idempotent:
# no PR when already pinned, or when the bump branch already exists on the remote.
open_bump_pr() {
  local tool="$1" version="$2" var="$3"
  local cur; cur=$(current_pin "$var")
  if [ -z "$cur" ]; then
    log "could not read \$${var} from ${EXTERNALS}; skipping PR"
    return 0
  fi
  if [ "$cur" = "$version" ]; then
    log "${tool} pin already at ${version}; no PR"
    return 0
  fi
  local branch="mirror/${tool}-${version}"
  if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    log "branch ${branch} already exists on origin; skipping PR"
    return 0
  fi
  log "bumping \$${var}: ${cur} -> ${version}"
  git switch -c "$branch"
  sed -i -E "s/(\\\$${var}[[:space:]]*:=[[:space:]]*\")[^\"]+(\")/\1${version}\2/" "$EXTERNALS"
  git -c user.name="github-actions[bot]" \
      -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
      commit -am "chore(deps): mirror ${tool} ${cur} -> ${version}"
  git push -u origin "$branch"
  gh pr create --label dependencies --base main --head "$branch" \
    --title "chore(deps): mirror ${tool} ${cur} -> ${version}" \
    --body "Mirrored **${tool}** \`${cur}\` → \`${version}\` via \`mirror-externals.yml\` (release \`mirror-${tool}-${version}\`).

Merge, then run \`chezmoi apply\` on each machine. Nothing is applied automatically."
}
