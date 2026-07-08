## Purpose

定義如何讓 [Renovate](https://docs.renovatebot.com/) 自動追蹤 `home/.chezmoiexternal.toml` 裡釘住版本的第三方 CLI 工具:用行內 `# renovate:` 註解 + 一個 custom regex manager,讓 Renovate 偵測上游新版並開 PR(人工 review + `chezmoi apply` 才生效)。上游偵測或落地版面太雜的工具(jdtls / ffmpeg / dos2unix / vim)明確延後到 mirror 階段;自建的 statusline / passgen 不追蹤。
## Requirements
### Requirement: Renovate config detects external version pins
The repository SHALL contain a root `renovate.json` with a custom regex manager that targets `home/.chezmoiexternal.toml` and extracts the current version from each annotated pin. The config SHALL pass `renovate-config-validator`.

#### Scenario: Config validates
- **WHEN** `npx --yes renovate-config-validator` runs against `renovate.json`
- **THEN** it reports the config as valid with no errors

#### Scenario: Manager scopes only the externals file
- **WHEN** Renovate evaluates its custom manager `managerFilePatterns`
- **THEN** the pattern matches `home/.chezmoiexternal.toml` and no other file

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

### Requirement: Annotations do not change the deployed externals
Adding the annotation and exclusion comments SHALL NOT change which externals chezmoi deploys. Every external's `url`, `path`, and version SHALL be identical before and after this change; the only difference in the chezmoi-rendered output SHALL be added `#` comment lines (which the TOML parser ignores). The JDK entries, although refactored to version variables, SHALL render byte-identical URLs.

#### Scenario: Only comment lines differ in the rendered output
- **WHEN** `home/.chezmoiexternal.toml` is rendered by chezmoi before and after the change
- **THEN** every differing line is an added `#` comment, and no `[...]` table, `url`, or `path` line changes

#### Scenario: Refactored JDK entries render the original URLs
- **WHEN** the JDK entries (converted from hardcoded URLs to version variables) are rendered
- **THEN** each produces the exact same download URL as before the refactor

### Requirement: Updates go through human review
Renovate SHALL be configured without auto-merge so that every version bump is delivered as a pull request for human review before merge; deployment to a machine still requires a manual `chezmoi apply`. The self-built `statusline` and `passgen` release pins SHALL be excluded from Renovate.

#### Scenario: A bump arrives as a reviewable PR
- **WHEN** Renovate detects a newer version for an annotated tool
- **THEN** it opens a pull request editing only the pin's version value, and does not merge it automatically

#### Scenario: Self-built tools are not tracked
- **WHEN** Renovate scans the externals file
- **THEN** the `statusline` and `passgen` entries receive no bump annotation and no PR

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

