## Why

GnuPG for Windows is pinned by three hand-maintained variables in
`run_onchange_install-gnupg.ps1.tmpl` (`$gpgVersion`, `$gpgDate`, `$gpgSha256`).
Its source is gnupg.org — not a Renovate datasource — and the version is a
compound of semver + build date + SHA-256 that no Renovate regex manager can
derive. So gpg is the one managed tool whose version bumps are still fully
manual, and it silently drifts (the pin is already a release behind:
`2.5.20_20260513` vs upstream `2.5.21_20260702`).

## What Changes

- Add a `gnupg` detector to the existing `mirror-externals.yml` workflow that
  scrapes gnupg.org, computes the new version + date + SHA-256, and opens a
  reviewable bump PR — the same way the mirror tools' bumps already arrive.
- Introduce a **detect-only (no re-host)** mode to the mirroring workflow:
  unlike vim/jdtls/dos2unix, gnupg is NOT re-hosted (gnupg.org URLs are durable),
  so the gnupg job publishes no release and only opens a PR.
- The gnupg bump edits **three coupled variables** in a `.ps1.tmpl` script
  (not a single variable in `.chezmoiexternal.toml`), so it uses gnupg-specific
  bump/PR logic that leaves the vim/jdtls/dos2unix paths untouched.
- Fix a stale comment in `home/.chezmoiexternal.toml` (`gpg suite stays on scoop`)
  that Wave 8 (`gpg-off-scoop`) obsoleted.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `external-tool-mirroring`: the workflow gains a fourth tool (gnupg) and a
  detect-only variant — a job MAY detect an upstream version and open a bump PR
  **without** re-hosting a mirror release, and the pin it bumps MAY live in a
  chezmoi script with multiple coupled variables rather than a single
  `.chezmoiexternal.toml` variable.

## Impact

- **Workflow:** `.github/workflows/mirror-externals.yml` — matrix gains `gnupg`;
  header comment updated to note the detect-only tool.
- **New script:** `.github/scripts/mirror-gnupg.sh` — scrape + SHA lookup +
  gnupg-specific 3-variable bump/PR.
- **Shared helpers:** `.github/scripts/mirror-common.sh` — reused read-only
  (`log`, `validate_version`); existing `publish_mirror`/`open_bump_pr` left
  unchanged so vim/jdtls/dos2unix are unaffected.
- **Pinned file:** `home/run_onchange_install-gnupg.ps1.tmpl` — its three pin
  variables become the bump target (content unchanged by this change; only the
  automation that edits them is added).
- **Comment fix:** `home/.chezmoiexternal.toml`.
- No machine-facing behavior changes until a bump PR is merged and
  `chezmoi apply` is run.
