# external-tool-mirroring Specification

## Purpose
TBD - created by archiving change add-renovate-mirror-externals. Update Purpose after archive.
## Requirements
### Requirement: A mirror workflow re-hosts the messy-upstream tools
The repository SHALL contain a GitHub Actions workflow `.github/workflows/mirror-externals.yml` that handles the tools Renovate cannot track directly. Three of them — vim, jdtls, dos2unix — SHALL be re-hosted to this repo's own GitHub Releases; a fourth, gnupg, SHALL be handled in **detect-only** mode (version detection + bump PR, no re-hosted release — see the detect-only requirement below). The workflow SHALL run on a weekly schedule and SHALL also be manually triggerable via `workflow_dispatch`. Each tool SHALL be handled by an independent job so that one tool's failure does not block the others.

#### Scenario: Workflow exists with both triggers
- **WHEN** `.github/workflows/mirror-externals.yml` is read
- **THEN** it declares a `schedule` (weekly) trigger and a `workflow_dispatch` trigger, and contains a separate job for each of vim, jdtls, dos2unix, and gnupg

#### Scenario: Jobs are independent
- **WHEN** one tool's job fails (e.g. a checkver scrape breaks)
- **THEN** the other tools' jobs still run to completion

### Requirement: gnupg is detected but not re-hosted
The gnupg job SHALL determine the latest GnuPG-for-Windows version WITHOUT re-hosting any asset, because the upstream gnupg.org download URLs are durable and need no mirror. The job SHALL NOT publish a `mirror-gnupg-<version>` release and SHALL NOT download or repackage the installer; it only reads version metadata and opens a bump PR. In `workflow_dispatch` seed mode (`publish_only=true`) the gnupg job SHALL be a no-op, since it has nothing to publish.

#### Scenario: No mirror release is published for gnupg
- **WHEN** the gnupg job runs and detects a newer version
- **THEN** it opens a bump PR but creates no GitHub Release and uploads no asset

#### Scenario: Seed mode skips gnupg
- **WHEN** the workflow is dispatched with `publish_only=true`
- **THEN** the gnupg job performs no work (no publish, no PR)

### Requirement: gnupg version, date, and SHA-256 are detected from gnupg.org
The gnupg job SHALL read the target version and build date by scraping `https://www.gnupg.org/download/index.html` for `gnupg-w32-<version>_<date>.exe` (that page advertises only the single current Windows installer, so no release-line selection is needed). It SHALL then read that exact file's SHA-256 from `https://www.gnupg.org/download/integrity_check.html`, matching the full basename `gnupg-w32-<version>_<date>.exe` against a 64-hex-character hash so the SHA-256 entry is selected rather than the co-listed SHA-1 (40 hex) entry. A parse failure at either source SHALL fail the job loudly (non-zero exit) rather than pin a wrong or empty value.

#### Scenario: Version and date come from the download page
- **WHEN** the gnupg job scrapes `download/index.html`
- **THEN** it extracts the `<version>` and `<date>` from the single advertised `gnupg-w32-<version>_<date>.exe` filename

#### Scenario: SHA-256 is matched to the exact file
- **WHEN** the gnupg job reads `integrity_check.html`, which lists both a 40-hex SHA-1 and a 64-hex SHA-256 for that file (alongside other release lines)
- **THEN** it selects the 64-hex SHA-256 whose line ends with `gnupg-w32-<version>_<date>.exe`, not the SHA-1 and not another version's hash

#### Scenario: A scrape failure fails loudly
- **WHEN** `download/index.html` yields no `gnupg-w32-...` match, or the matched file has no SHA-256 row in `integrity_check.html`
- **THEN** the job exits non-zero and opens no PR

### Requirement: The gnupg bump edits three coupled variables in the install script
When the detected version differs from the current pin, the gnupg job SHALL open a pull request that edits all three pin variables — `$gpgVersion`, `$gpgDate`, and `$gpgSha256` — in `home/run_onchange_install-gnupg.ps1.tmpl` together in one commit, labelled `dependencies`, and SHALL NOT merge it. The idempotency key SHALL be an open PR for the target version's branch, and the up-to-date check SHALL compare against the current `$gpgVersion` pin. Deployment SHALL still require a manual `chezmoi apply` after merge. This logic SHALL be gnupg-specific and SHALL NOT alter the single-variable `.chezmoiexternal.toml` bump path used by vim/jdtls/dos2unix.

#### Scenario: A newer version opens a three-variable PR
- **WHEN** the detected `gnupg-w32` version differs from `$gpgVersion` in the install script
- **THEN** a `dependencies`-labelled PR is opened that updates `$gpgVersion`, `$gpgDate`, and `$gpgSha256` in one commit, and it is not merged

#### Scenario: Up-to-date pin opens no PR
- **WHEN** `$gpgVersion` already equals the detected version
- **THEN** the gnupg job opens no PR

#### Scenario: A partial prior run is recoverable
- **WHEN** a prior gnupg run pushed the bump branch but failed before the PR was created
- **THEN** a rerun re-pushes the branch and opens the PR (idempotency keys on the open PR, not on branch existence)

### Requirement: Each tool's upstream version is detected automatically
Each job SHALL determine the latest upstream version using that tool's real version feed: vim from the latest `vim/vim-win32-installer` GitHub release tag; jdtls from `https://download.eclipse.org/jdtls/snapshots/latest.txt`; dos2unix by scraping the waterlander page for `Stable version:\s+([\d.]+)`.

#### Scenario: Version comes from the tool's real feed
- **WHEN** the vim job runs
- **THEN** it reads the newest `vim/vim-win32-installer` release tag as the target version

#### Scenario: A scrape failure fails loudly
- **WHEN** an HTML/text version source (jdtls `latest.txt` or the dos2unix page) cannot be parsed
- **THEN** the job fails with a non-zero status rather than publishing or pinning a wrong version

### Requirement: Upstream artifacts are repackaged into chezmoi-friendly assets
Each job SHALL normalize its upstream artifact so chezmoi can consume it and so no version string is embedded in an on-disk path. vim SHALL be repackaged so the versioned `vimXX/` runtime directory is renamed to a stable `current/`. jdtls SHALL be re-hosted verbatim as the upstream `.tar.gz`. dos2unix SHALL be reduced to the single `dos2unix.exe`.

#### Scenario: vim runtime dir is version-stable
- **WHEN** the vim mirror asset is extracted
- **THEN** the runtime directory is named `current`, with no MAJOR.MINOR version in its name

#### Scenario: jdtls is re-hosted verbatim
- **WHEN** the jdtls mirror asset is compared to the upstream snapshot tarball
- **THEN** it is byte-identical, re-hosted only to survive upstream pruning

### Requirement: Mirror releases are versioned and record provenance
Each published release SHALL use a version-bearing tag `mirror-<tool>-<version>` and version-bearing asset filenames so the download URL is stable and self-describing. Because a repackaged asset's bytes differ from the upstream file, each release's notes SHALL record the upstream source URL, the upstream version, and the sha256 checksum of the upstream file.

#### Scenario: Release is tagged and traceable
- **WHEN** a new mirror release is published for a tool
- **THEN** its tag is `mirror-<tool>-<version>` and its notes contain the upstream URL, upstream version, and the upstream file's sha256

#### Scenario: Re-runs are idempotent
- **WHEN** a job runs and `mirror-<tool>-<version>` already exists as a release
- **THEN** it does not republish the release and does not open a duplicate PR

### Requirement: Bumps arrive as reviewable PRs, never auto-applied
A job SHALL, when it mirrors (or, for gnupg, detects) a version newer than the current
pin, open a pull request that edits only that tool's pin, labelled `dependencies`,
one PR per tool. To let the PR pass through the same `validate-externals` required
check as Renovate's PRs, the mirror workflow SHALL create these PRs using a personal
access token (`MIRROR_PAT`) rather than the default `GITHUB_TOKEN` (whose events do
not trigger further workflows). Each PR SHALL enable GitHub auto-merge with squash so
it merges once the validate check passes. The job SHALL NOT merge the PR directly
without the check. Deployment to a machine SHALL still require a manual `chezmoi apply`
after merge.

#### Scenario: A newer mirror opens a pin PR that auto-merges on green
- **WHEN** a job publishes a mirror release (or gnupg detects a new version) whose version differs from the pin
- **THEN** it opens a `dependencies`-labelled PR via `MIRROR_PAT` and enables squash auto-merge, which completes only after `validate-externals` succeeds

#### Scenario: Up-to-date pin opens no PR
- **WHEN** the current pin already equals the newest mirrored version
- **THEN** the job opens no PR

#### Scenario: The PR triggers the validate check
- **WHEN** the mirror PR is created
- **THEN** because it was created with `MIRROR_PAT`, the `validate-externals` workflow runs on it (a `GITHUB_TOKEN`-created PR would not trigger it)

