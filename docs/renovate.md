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

| Tool | Why |
|------|-----|
| `statusline`, `passgen` | self-built (own GitHub Releases) |

## Mirror phase (self-hosted tools)

Three tools cannot be tracked by a Renovate datasource *and* be handed to chezmoi
directly, so a GitHub Actions workflow ([`.github/workflows/mirror-externals.yml`](../.github/workflows/mirror-externals.yml))
re-hosts and layout-normalizes them under this repo's own Releases:

| Tool | Why the upstream is hard | What the mirror does |
|------|--------------------------|----------------------|
| `vim` | upstream names the runtime dir `vimXX` by MAJOR.MINOR, coupling the version into 15 `.cmd` wrappers | renames it to a stable `current/` so the wrappers never change |
| `jdtls` | Eclipse `snapshots/` builds are pruned over time (a pinned URL eventually 404s) | re-hosts the tarball verbatim for durability |
| `dos2unix` | version lives only on an HTML page (waterlander.net), no datasource | scrapes the version, re-hosts the single `.exe` at a stable URL |

The workflow runs weekly (plus `workflow_dispatch`), publishes `mirror-<tool>-<version>`
releases (notes record the upstream URL + version + sha256), and opens a one-per-tool
pin-bump PR labelled `dependencies` — so these bumps arrive the same way Renovate's do,
just from our own workflow. The three pins stay `# renovate: ignore`; nothing auto-merges,
and `chezmoi apply` is still manual. Seed mode (`workflow_dispatch` with `publish_only=true`)
creates the releases without opening PRs.

**ffmpeg is not mirrored.** GyanD publishes a clean-semver `.zip` (scoop's original
source, one of the two builds endorsed on ffmpeg.org), so it is a normal Renovate pin
on `GyanD/codexffmpeg` like every other tracked tool.

## Auto-merge

Bump PRs no longer need a manual click. A required CI check validates each one, and
low-risk updates merge themselves once it passes.

- **What auto-merges:** `patch`, `minor`, and `pin` updates (Renovate `automerge` via
  GitHub native auto-merge). **`major` stays manual** — it may carry breaking changes.
  A `minimumReleaseAge` of 3 days holds a bump back until the upstream release has
  settled (catches yanked/hotfixed releases for free).
- **The gate:** [`.github/workflows/validate-externals.yml`](../.github/workflows/validate-externals.yml)
  runs on every PR to `main`. It reports a single `gate` status check. On a PR that
  touches neither `home/.chezmoiexternal.toml` nor `home/run_onchange_install-gnupg.ps1.tmpl`
  the gate passes instantly (so unrelated PRs are never blocked). On a bump PR it, per
  OS (ubuntu/macos/windows), renders the externals with chezmoi and HEAD-checks every
  download URL, and verifies the gnupg pin's SHA-256 against the real installer. Any
  failure fails the gate and blocks the merge.
- **Mirror PRs too:** the `mirror-externals` workflow opens its PRs with a PAT (not the
  default token, whose PRs don't trigger other workflows) and enables squash auto-merge,
  so vim/jdtls/dos2unix/gnupg bumps flow through the same gate.
- **Machines are still safe:** auto-merge only lands the pin on `main`. Nothing changes
  a machine until you run `chezmoi apply`, where the install scripts re-verify (e.g. the
  gnupg SHA-256).

### One-time manual setup

These are GitHub settings, not code — do them once:

1. **Settings → General → Pull Requests → "Allow auto-merge"**: ON.
2. **Branch protection / ruleset on `main`**: require the **`gate`** status check
   (from `validate-externals`). This is what makes auto-merge wait for validation.
3. **`MIRROR_PAT` secret**: a fine-grained PAT scoped to this repo with
   **Contents: Read/Write** + **Pull requests: Read/Write**, saved as the Actions secret
   `MIRROR_PAT`. The mirror workflow uses it so its PRs trigger the gate. ⚠ Fine-grained
   PATs expire (≤1 year) — note the expiry: if it lapses, mirror bump PRs stop triggering
   the check and their auto-merge stalls (they wait, they never mis-merge).

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
npm exec --yes --package=renovate -- renovate-config-validator renovate.json
```
