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

# validate_version <version> — abort unless it is a plain dotted/dashed numeric
# (e.g. 9.2.0782, 1.61.0-202607070104, 7.5.6). Upstream version strings flow into
# a sed replacement, a branch name, and gh args, so reject anything that could
# carry sed-special or shell-meaningful characters before it gets there.
validate_version() {
  case "$1" in
    ''|*[!0-9.-]*) log "refusing suspicious version string: [$1]"; return 1 ;;
  esac
  return 0
}

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
# Opens a one-line pin-bump PR when the pin differs from <version>.
# Idempotency keys on an OPEN PR, not on branch existence: if a prior run pushed
# the branch but then failed to create the PR (missing label, disabled setting,
# API hiccup), a branch-existence guard would suppress the retry forever. Keying
# on the PR lets a rerun recover — it re-pushes the branch and (re)opens the PR.
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
  if [ -n "$(gh pr list --head "$branch" --state open --json number --jq '.[0].number' 2>/dev/null)" ]; then
    log "PR for ${branch} already open; skipping"
    return 0
  fi
  log "bumping \$${var}: ${cur} -> ${version}"
  git switch -C "$branch"   # -C: reset a branch a prior failed run may have left
  sed -i -E "s/(\\\$${var}[[:space:]]*:=[[:space:]]*\")[^\"]+(\")/\1${version}\2/" "$EXTERNALS"
  git -c user.name="github-actions[bot]" \
      -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
      commit -am "chore(deps): mirror ${tool} ${cur} -> ${version}"
  git push --force origin "$branch"
  # Ensure the label exists so `gh pr create --label` can't fail on a missing one.
  gh label create dependencies --color 0366d6 --description "Dependency updates" 2>/dev/null || true
  gh pr create --label dependencies --base main --head "$branch" \
    --title "chore(deps): mirror ${tool} ${cur} -> ${version}" \
    --body "Mirrored **${tool}** \`${cur}\` → \`${version}\` via \`mirror-externals.yml\` (release \`mirror-${tool}-${version}\`).

Squash auto-merge is enabled: this merges once the \`validate-externals\` check passes. Nothing reaches a machine until you run \`chezmoi apply\`."
  # Auto-merge once the required validate-externals check is green (GitHub waits for it).
  # Don't fail the job if this can't be enabled (e.g. repo "Allow auto-merge" off) — the
  # PR is already open and recoverable — but log it rather than swallow it silently.
  gh pr merge --auto --squash --delete-branch "$branch" \
    || log "could not enable auto-merge for ${branch} (is repo 'Allow auto-merge' on + branch protection set?); PR left open for manual merge"
}
