## ADDED Requirements

### Requirement: A mirror workflow re-hosts the messy-upstream tools
The repository SHALL contain a GitHub Actions workflow `.github/workflows/mirror-externals.yml` that mirrors the three tools Renovate cannot track directly — vim, jdtls, dos2unix — to this repo's own GitHub Releases. The workflow SHALL run on a weekly schedule and SHALL also be manually triggerable via `workflow_dispatch`. Each tool SHALL be handled by an independent job so that one tool's failure does not block the others.

#### Scenario: Workflow exists with both triggers
- **WHEN** `.github/workflows/mirror-externals.yml` is read
- **THEN** it declares a `schedule` (weekly) trigger and a `workflow_dispatch` trigger, and contains a separate job for each of vim, jdtls, and dos2unix

#### Scenario: Jobs are independent
- **WHEN** one tool's job fails (e.g. a checver scrape breaks)
- **THEN** the other two tools' jobs still run to completion

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
When a job mirrors a version newer than the current pin, it SHALL open a pull request that edits only that tool's version variable in `home/.chezmoiexternal.toml`, labelled `dependencies`, one PR per tool, and SHALL NOT merge it automatically. Deployment to a machine SHALL still require a manual `chezmoi apply` after merge.

#### Scenario: A newer mirror opens a pin PR
- **WHEN** a job publishes a mirror release whose version differs from the pin in `home/.chezmoiexternal.toml`
- **THEN** it opens a `dependencies`-labelled PR changing only that tool's version variable, and does not merge it

#### Scenario: Up-to-date pin opens no PR
- **WHEN** the current pin already equals the newest mirrored version
- **THEN** the job opens no PR
