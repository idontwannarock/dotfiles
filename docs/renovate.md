# Renovate auto-bump for external tool versions

[Renovate](https://docs.renovatebot.com/) watches the upstream of each CLI tool
pinned in [`home/.chezmoiexternal.toml`](../home/.chezmoiexternal.toml) and opens
a pull request when a newer version is available. `patch`, `minor`, and `pin`
bumps merge themselves once the `gate` check passes; `major` waits for you (see
[Auto-merge](#auto-merge)). Either way nothing changes a machine until you run
`chezmoi apply`.

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

## Two files carry pins, not one

The custom manager scans both `home/.chezmoiexternal.toml` and
`home/run_install-00-opt-archives.ps1.tmpl`. The annotation format is identical in
each; only the location differs.

The second file exists because six entries — `go` and the five JDKs — were too
expensive to keep as externals. chezmoi re-reads and re-hashes every managed file
on every apply, so it can tell you edited one. Measured on Windows with
`chezmoi apply --dry-run`:

| | managed entries | time |
|---|---|---|
| all externals | 23,466 | 26.3s |
| `go` off | 6,113 | 24.2s |
| five JDKs off | 20,673 | 19.0s |
| both off | 3,320 | 15.5s |

Cost tracks **bytes**, not file count — roughly 194 MB/s. Those six directories
are 1.7 GB and 11 of the 26 seconds. They now reinstall when their URL changes
instead, which is the trigger that was wanted anyway. That file's header carries
the design and the force-reinstall commands.

`validate-externals` HEAD-checks the URLs from both files.

## Why a version in the URL is what makes an external cheap

chezmoi's default refresh mode is `auto`, so it decides per entry, by cache age
alone, whether to go to the network. An entry with no `refreshPeriod` is fetched
once and then served from cache forever.

That is safe precisely because the pin lives in the URL. chezmoi keys its cache
on a hash of the URL, so the Renovate PR that rewrites a version string also
rewrites the URL, misses the cache, and downloads the new version on its own. No
`refreshPeriod` is needed, and none should be added.

The opposite case is the trap: an entry whose URL is rolling — `latest`, a
branch, a moving tag — **must** set `refreshPeriod`, or it will silently never
update on any machine. Only `statusline` and `passgen` are rolling today, and
both carry `refreshPeriod = "1h"`.

Passing `-R` (`--refresh-externals`, which defaults to `always`) overrides all of
this and re-fetches every entry: 151.2s against 39.5s cached on Windows. Do not
reach for it out of habit — 33 of the 35 cannot have changed.

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
- **Hosted outside GitHub:** `glab` uses `gitlab-releases` with
  `depName=gitlab-org/cli` — the only non-GitHub datasource in the file. Its tags
  carry a `v` prefix the asset filenames omit, hence the `extractVersion`.
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
just from our own workflow. The three pins stay `# renovate: ignore` so Renovate leaves
them alone, but their PRs go through the same `gate` and the same auto-merge as everything
else (see [Auto-merge](#auto-merge)); `chezmoi apply` is still manual. Seed mode
(`workflow_dispatch` with `publish_only=true`) creates the releases without opening PRs.

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

### PR throughput, and why a tool can starve

The queue is rate-limited, and Renovate creates branches in alphabetical order. If the
limit cuts the queue short, the same tail of the alphabet is dropped every week — the
tool never gets a PR, and its pin silently rots.

This happened. `config:recommended` sets `prHourlyLimit: 2`, and the schedule window is
`before 6am on monday`, in which Mend runs the job only 1–4 times. That capped the repo
at 2–8 bump PRs per week. Everything alphabetically past `nxtrace` never made it:
`ryanoasis/nerd-fonts`, `starship/starship`, `yt-dlp/yt-dlp` and `zellij-org/zellij`
each sat in the dashboard's **Awaiting Schedule** list for months. yt-dlp fell 5 months
behind this way.

`renovate.json` now sets `prHourlyLimit: 6`. To confirm the queue drains, read the
Dependency Dashboard issue after a Monday: **Awaiting Schedule** should hold only
`major` updates, which stay manual by design.

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
3. Bump PRs then arrive on the weekly schedule. Low-risk ones land on their own;
   `major` needs your review. Either way, `chezmoi apply` to pick them up.

Validate config changes locally with:

```bash
npm exec --yes --package=renovate -- renovate-config-validator renovate.json
```
