# Design — add-gnupg-checkver

## Context

The mirror-externals workflow already exists and handles vim/jdtls/dos2unix:
each `mirror-<tool>.sh` sources `mirror-common.sh`, optionally re-hosts via
`publish_mirror`, then bumps a single `.chezmoiexternal.toml` variable via
`open_bump_pr`. gnupg is a poor fit for that shape in three ways, which drive
the decisions below:

1. Its pin lives in `home/run_onchange_install-gnupg.ps1.tmpl`, not
   `.chezmoiexternal.toml`, and is **three coupled variables** (`$gpgVersion`,
   `$gpgDate`, `$gpgSha256`), not one.
2. It needs **no re-host** — gnupg.org URLs are durable (unlike jdtls's pruned
   Eclipse snapshots or dos2unix's HTML-only page).
3. Its version metadata comes from **two** gnupg.org pages, and the SHA it pins
   is SHA-256 while the page also lists SHA-1 for the same file.

Authoritative reference for the scrape mechanics: scoop's `gpg.json` manifest
(`checkver.url` = `download/index.html`, regex `gnupg-w32-([\d.]+)_(?<date>\d+)\.exe`;
`autoupdate.hash.url` = `download/integrity_check.html`). We reuse its sources
but pin SHA-256 (scoop pins SHA-1).

## Goals / Non-Goals

**Goals**
- Detect a newer GnuPG-w32 automatically and open a reviewable 3-variable bump PR.
- Reuse the existing workflow's schedule, `dependencies` label, and
  merge-then-`chezmoi apply` discipline.
- Leave the vim/jdtls/dos2unix code paths byte-for-byte unchanged.

**Non-Goals**
- Re-hosting the GnuPG installer (durable upstream; unnecessary).
- Auto-merging, or verifying the installer download in CI (the install-time
  SHA-256 check in `install-gnupg.ps1.tmpl` already guards the machine).
- Tracking multiple GnuPG release lines (index.html advertises only one).

## Decisions

### D1 — gnupg-specific bump/PR logic, common.sh untouched
`open_bump_pr` is single-variable, hardcodes `EXTERNALS=.chezmoiexternal.toml`,
and phrases its commit/PR as "mirror". Generalizing it would risk the three
working tools. Instead `mirror-gnupg.sh` sources `mirror-common.sh` only for the
safe read-only helpers (`log`, `validate_version`) and implements its own
`current_gpg_pin` + bump/PR inline. Commit/PR wording is "bump" (no re-host).

### D2 — two-source scrape, fail-loud
- Version + date: `curl` `download/index.html`, grep
  `gnupg-w32-([0-9.]+)_([0-9]+)\.exe`, take the first (page lists one). Empty →
  exit 1.
- SHA-256: `curl` `integrity_check.html`, select the line matching
  `^[0-9a-f]{64}  gnupg-w32-<ver>_<date>\.exe$`. The 64-hex anchor discriminates
  SHA-256 from the co-listed 40-hex SHA-1; the full basename discriminates the
  target version from other release lines (e.g. 2.2.44 LTS). No match → exit 1.

### D3 — validation
`validate_version` already accepts `[0-9.]` — reuse for `$gpgVersion`. `$gpgDate`
is 8 digits (also passes). `$gpgSha256` gets a dedicated `^[0-9a-f]{64}$` guard
before it flows into `sed`, since it is not a "version" but is user-influenced
input from a scraped page.

### D4 — three-variable atomic sed + idempotency
One commit runs three `sed -i` edits against `install-gnupg.ps1.tmpl`, matching
the `{{- $gpgX := "…" }}` template lines. Branch `mirror/gnupg-<version>`;
idempotency keys on an **open** PR for that branch (mirrors the recover-on-rerun
rationale already documented in `open_bump_pr`). Up-to-date check compares the
detected version to the current `$gpgVersion`.

### D5 — matrix + seed-mode no-op
Add `gnupg` to the `tool:` matrix. `mirror-gnupg.sh` honors `PUBLISH_ONLY=true`
by exiting early (nothing to publish). Workflow header comment updated to note
that gnupg is detect-only (no re-host).

## Risks / Trade-offs

- **integrity_check.html format drift** → the SHA-256 regex could stop matching.
  Mitigated by fail-loud (D2): a broken scrape opens no PR and the pin stays put,
  rather than pinning a wrong hash. `fail-fast: false` already isolates it from
  the other jobs.
- **index.html adds a second gnupg-w32 line** (e.g. a future LTS Windows build) →
  "take the first" could pick the wrong one. Low likelihood (historically one).
  If it happens the fix is a one-line filter; the fail-loud floor still prevents
  a bad pin.
- **CI can't dry-run the machine effect** → acceptable; the PR is reviewed and
  the install script re-verifies the SHA-256 on the actual download at apply.

## Migration

None. No machine changes until the first bump PR (2.5.20 → 2.5.21) is merged and
`chezmoi apply` runs — identical to how vim/jdtls/dos2unix bumps already land.
