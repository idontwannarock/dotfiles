## ADDED Requirements

### Requirement: Renovate config detects external version pins
The repository SHALL contain a root `renovate.json` with a custom regex manager that targets `home/.chezmoiexternal.toml` and extracts the current version from each annotated pin. The config SHALL pass `renovate-config-validator`.

#### Scenario: Config validates
- **WHEN** `npx --yes renovate-config-validator` runs against `renovate.json`
- **THEN** it reports the config as valid with no errors

#### Scenario: Manager scopes only the externals file
- **WHEN** Renovate evaluates its custom manager `managerFilePatterns`
- **THEN** the pattern matches `home/.chezmoiexternal.toml` and no other file

### Requirement: Auto-bumpable pins carry datasource annotations
Every Tier A and Tier B version pin in `home/.chezmoiexternal.toml` SHALL be preceded by an inline `# renovate: datasource=… depName=…` comment (with `versioning=` / `extractVersion=` where the tag scheme requires it) on its own line directly above the `{{- $…Version := "…" }}` assignment. Each annotation's `datasource`/`depName` SHALL match the tool's real upstream version feed per the design's mapping table.

#### Scenario: A GitHub-release tool is annotated
- **WHEN** the `starship` pin is read
- **THEN** the line above it is `# renovate: datasource=github-releases depName=starship/starship`

#### Scenario: A non-GitHub-hosted tool maps to its real version feed
- **WHEN** the `kubectl` pin (downloaded from dl.k8s.io) is read
- **THEN** its annotation uses a datasource that tracks the upstream Kubernetes version, not the download host

#### Scenario: A shared version variable is annotated once
- **WHEN** a single `$Version` variable feeds multiple external entries (e.g. kubelogin)
- **THEN** exactly one annotation precedes the variable assignment, not one per external entry

### Requirement: Messy-upstream tools are explicitly deferred
Tools whose upstream detection or on-disk layout is messy — jdtls, ffmpeg, dos2unix, and vim — SHALL NOT receive a bump-enabling annotation in this change. Each SHALL instead carry a short `# renovate: ignore` comment recording that it is deferred to the mirror phase and why. Renovate SHALL NOT open bump PRs for these pins.

#### Scenario: A deferred tool is marked, not bumped
- **WHEN** the `jdtls` pin is read
- **THEN** it carries a comment stating it is deferred to the mirror phase with the reason, and no `# renovate: datasource=…` enabling annotation

#### Scenario: vim is deferred, not annotated
- **WHEN** the `vim` pin is read
- **THEN** it carries a deferral comment and no bump annotation (its `vim92` wrapper coupling is resolved by mirror-side layout normalization, not by Renovate)

### Requirement: Annotations do not change chezmoi output
Adding the annotation and exclusion comments SHALL NOT change the result of rendering `home/.chezmoiexternal.toml`. The deployed externals, URLs, and versions SHALL be identical before and after this change.

#### Scenario: Rendered output is unchanged
- **WHEN** `home/.chezmoiexternal.toml` is rendered by chezmoi before and after the comments are added
- **THEN** the two rendered outputs are byte-identical

### Requirement: Updates go through human review
Renovate SHALL be configured without auto-merge so that every version bump is delivered as a pull request for human review before merge; deployment to a machine still requires a manual `chezmoi apply`. The self-built `statusline` and `passgen` release pins SHALL be excluded from Renovate.

#### Scenario: A bump arrives as a reviewable PR
- **WHEN** Renovate detects a newer version for an annotated tool
- **THEN** it opens a pull request editing only the pin's version value, and does not merge it automatically

#### Scenario: Self-built tools are not tracked
- **WHEN** Renovate scans the externals file
- **THEN** the `statusline` and `passgen` entries receive no bump annotation and no PR
