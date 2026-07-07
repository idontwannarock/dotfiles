## RENAMED Requirements

- FROM: `### Requirement: Messy-upstream tools are explicitly deferred`
- TO: `### Requirement: Messy-upstream tools are mirrored, not Renovate-tracked`

## MODIFIED Requirements

### Requirement: Auto-bumpable pins carry datasource annotations
Every Tier A and Tier B version pin in `home/.chezmoiexternal.toml` SHALL be preceded by an inline `# renovate: datasource=… depName=…` comment (with `versioning=` / `extractVersion=` where the tag scheme requires it) on its own line directly above the `{{- $…Version := "…" }}` assignment. Each annotation's `datasource`/`depName` SHALL match the tool's real upstream version feed per the design's mapping table. ffmpeg SHALL be tracked this way against `GyanD/codexffmpeg` (it is not mirrored).

#### Scenario: A GitHub-release tool is annotated
- **WHEN** the `starship` pin is read
- **THEN** the line above it is `# renovate: datasource=github-releases depName=starship/starship`

#### Scenario: A non-GitHub-hosted tool maps to its real version feed
- **WHEN** the `kubectl` pin (downloaded from dl.k8s.io) is read
- **THEN** its annotation uses a datasource that tracks the upstream Kubernetes version, not the download host

#### Scenario: A shared version variable is annotated once
- **WHEN** a single `$Version` variable feeds multiple external entries (e.g. kubelogin)
- **THEN** exactly one annotation precedes the variable assignment, not one per external entry

#### Scenario: ffmpeg is annotated to its GyanD source
- **WHEN** the `ffmpeg` pin is read
- **THEN** the line above it is `# renovate: datasource=github-releases depName=GyanD/codexffmpeg`, and its three externals download GyanD's `.zip` via a single `$ffmpegVersion` variable in the URL and the internal `path`

### Requirement: Messy-upstream tools are mirrored, not Renovate-tracked
Tools whose upstream detection or on-disk layout is messy — jdtls, vim, and dos2unix — SHALL NOT receive a Renovate bump-enabling annotation. Instead, each SHALL be mirrored to this repo's own GitHub Releases by the `external-tool-mirroring` workflow, and its external in `home/.chezmoiexternal.toml` SHALL point at that mirror release. Each SHALL carry a short `# renovate: ignore` comment recording that it is mirrored by `mirror-externals.yml`. Renovate SHALL NOT open bump PRs for these pins (the mirror workflow opens them instead). ffmpeg is NOT in this set — it is a directly-annotated Renovate pin.

#### Scenario: A mirrored tool is ignored by Renovate, bumped by the workflow
- **WHEN** the `jdtls` pin is read
- **THEN** it carries a `# renovate: ignore` comment stating it is mirrored by `mirror-externals.yml`, has no `# renovate: datasource=…` enabling annotation, and its `url` points at a `mirror-jdtls-*` release in this repo

#### Scenario: vim's wrapper coupling is resolved by mirroring
- **WHEN** the `vim` pin and its `.cmd` wrappers are read
- **THEN** the pin carries a mirror `# renovate: ignore` comment and points at a `mirror-vim-*` release, and the wrappers reference the version-stable `current` runtime directory rather than a `vimXX` name

#### Scenario: Renovate opens no PR for a mirrored tool
- **WHEN** Renovate scans `home/.chezmoiexternal.toml`
- **THEN** the vim, jdtls, and dos2unix pins receive no bump annotation and no Renovate PR
