## Why

`home/.chezmoiexternal.toml` pins ~30 third-party CLI tools / toolchains to explicit versions (e.g. `{{- $starshipVersion := "1.25.1" }}`). Today every bump is manual: notice a release, edit the version string, `chezmoi apply`. Nothing watches upstream, so tools silently drift behind and security fixes are missed. We want a bot to periodically check upstream and open a PR per outdated pin, keeping a human review + merge gate.

## What Changes

- Add a `renovate.json` at repo root configured with **custom regex managers** that detect version pins in `home/.chezmoiexternal.toml` and map each to the correct Renovate datasource.
- Annotate the auto-bumpable version-pin lines in `home/.chezmoiexternal.toml` with inline `# renovate: datasource=… depName=… versioning=…` comments (the documented best practice for heterogeneous files). These are TOML comments and pass through chezmoi templating untouched.
- Categorise the externals into three tiers and document the tiering:
  - **Tier A — auto-bumpable** via `github-releases` (most tools) or a dedicated datasource (`golang-version` for Go).
  - **Tier B — auto-bumpable with care** (non-GitHub URL but a usable upstream version source, e.g. kubectl).
  - **Tier C — manual / not automatable** (snapshot or autobuild assets with no stable version feed: `jdtls`, BtbN `ffmpeg`, `dos2unix`, and any tool whose tag/asset scheme Renovate cannot track). These are explicitly excluded from Renovate and stay manual, with a comment saying why.
- Enable Renovate on the repo (GitHub App / hosted Renovate) so it runs on a schedule and opens bump PRs; merging + `chezmoi apply` stays a human step.

Explicitly **out of scope** (separate future change): self-hosting binaries by mirroring them to our own GitHub Releases under a unified `external` tag. This change keeps all externals pointing at their current upstream URLs. The self-built `statusline-latest` / `passgen-latest` releases are untouched and are excluded from Renovate.

## Capabilities

### New Capabilities
- `external-version-automation`: Renovate-driven detection and PR-based bumping of the version pins in `home/.chezmoiexternal.toml`, including the annotation convention, the datasource mapping per tool, and the auto-bumpable-vs-manual tiering rules.

### Modified Capabilities
<!-- None. tool-dependencies' install strategy is unchanged; this only adds automation around how its version pins are maintained. -->

## Impact

- **New file**: `renovate.json` (repo root).
- **Edited file**: `home/.chezmoiexternal.toml` — inline `# renovate:` annotation comments added above Tier A/B version-pin lines; Tier C lines get a short "manual: <reason>" comment. No URL, version value, or behavior changes — `chezmoi apply` output is byte-identical.
- **External service**: Renovate must be enabled on the GitHub repo (one-time onboarding PR). No CI secrets required for public repos; a `GITHUB_TOKEN` may be needed to avoid GitHub API rate limits on the datasource lookups.
- No change to deployed machines until a bump PR is merged and `chezmoi apply` is run.
