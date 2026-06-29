# Renovate auto-bump for external tool versions

[Renovate](https://docs.renovatebot.com/) watches the upstream of each CLI tool
pinned in [`home/.chezmoiexternal.toml`](../home/.chezmoiexternal.toml) and opens
a pull request when a newer version is available. Merging a PR + running
`chezmoi apply` is the only manual step — nothing auto-merges, nothing changes a
machine until you apply.

## How it works

`renovate.json` (repo root) defines **one custom regex manager** that reads inline
annotation comments in the externals file:

```toml
# renovate: datasource=github-releases depName=starship/starship
{{- $starshipVersion := "1.25.1" }}
```

Renovate does the rest: query the datasource for available versions, compare
against the pin, and open a PR editing just the version string. The annotation is
a static one-liner — you never write version-comparison logic.

These are TOML comments, so they do not change what `chezmoi apply` deploys
(verified by a before/after render diff).

## Adding a new tool

Add **one** comment line directly above the tool's `{{- $xVersion := "…" }}` pin:

```toml
# renovate: datasource=github-releases depName=<org>/<repo>
```

Optional fields: `versioning=<scheme>` (e.g. `loose` for CalVer), and
`extractVersion=<regex>` when the tag carries a prefix (e.g.
`extractVersion=^v(?<version>.+)$`). A pin with **no** comment is not tracked.

## Datasource tiers

- **Auto (most tools):** `github-releases`; Go uses `golang-version`, Maven uses
  the `maven` central artifact.
- **Version source ≠ download host:** `kubectl` (binary from dl.k8s.io, version
  from `kubernetes/kubernetes`), `maven`, `docker` CLI (binary from
  download.docker.com, version from `docker/cli`).
- **JDKs:** each Temurin major (`adoptium/temurinNN-binaries`) is its own repo,
  so a bump can never cross majors. The `+build` suffix needs the regex
  versioning in `renovate.json` packageRules; JDK 8's legacy `8uNNN-bNN` scheme
  has its own.

## Intentionally not tracked

| Tool | Why | Plan |
|------|-----|------|
| `statusline`, `passgen` | self-built (own GitHub Releases) | n/a |
| `jdtls` | Eclipse snapshot + timestamp, builds pruned | mirror phase |
| `ffmpeg` | BtbN git-describe asset filename not derivable; chezmoi can't extract GyanD's `.7z` | mirror phase |
| `dos2unix` | waterlander.net HTML page, no off-the-shelf datasource | mirror phase |
| `vim` | `vim92` runtime dir coupled to 15 `.cmd` wrappers — fixed by mirror-side layout normalization | mirror phase |

The "mirror phase" is a future change: a GitHub Actions workflow re-hosts (and
normalizes the layout of) these tools under our own Releases, after which they
become clean one-line annotations like everything else.

## Enabling

Renovate runs as the hosted **GitHub App** (free for this public repo; runs on
Mend's infra, uses no GitHub Actions minutes):

1. Install the Renovate app on `idontwannarock/dotfiles` from the GitHub
   Marketplace.
2. Merge its onboarding PR.
3. Bump PRs then arrive on the weekly schedule; review + merge, then
   `chezmoi apply`.

Validate config changes locally with:

```bash
npx --yes -p renovate renovate-config-validator renovate.json
```
