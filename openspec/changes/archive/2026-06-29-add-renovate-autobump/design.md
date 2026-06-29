## Context

`home/.chezmoiexternal.toml` pins ~30 third-party tools to explicit versions. Almost every "clean" pin follows one uniform shape — a chezmoi Go-template assignment:

```
{{- $starshipVersion := "1.25.1" }}
```

The version variable is reused in the download `url` and (where relevant) the archive-internal `path`, so a single edit keeps the whole entry consistent. This uniformity makes a single regex manager viable.

Renovate is the community-standard "watch upstream, open a bump PR" tool. For a heterogeneous file like this — every tool a different upstream, tag scheme, and datasource — the documented best practice is **inline `# renovate:` comment annotations** read by one custom regex manager, not one hand-written manager per tool. Confirmed current syntax (Renovate 41.x): `customManagers[].customType: "regex"`, `managerFilePatterns`, named capture groups `datasource` / `depName` / `currentValue` / `versioning` / `extractVersion`.

A key division emerged during design: **whether Renovate can compute the new download URL from a new version**. That needs (1) a datasource reporting the latest version AND (2) a URL/asset filename derivable from that version. Tools that fail (2) — because the upstream embeds a git hash, a build timestamp, or only ships a chezmoi-unfriendly archive format — are not made automatable by a Renovate annotation. The right home for *their* detection logic is the future mirror workflow (Phase 2), which can also **normalize** their on-disk layout. They are therefore deferred, not forced into a brittle custom datasource now.

## Goals / Non-Goals

**Goals:**
- One `renovate.json` + inline annotations that get Renovate opening per-tool bump PRs for every pin whose upstream is already clean (predictable version → URL).
- Correct datasource per tool; never a silently-wrong "latest".
- `chezmoi apply` output byte-identical before/after annotation (comments only) — except the JDK entries, which are refactored (see D4) with a verified-identical rendered URL.
- Explicit, documented deferral list for tools whose detection/layout belongs in the mirror phase.

**Non-Goals:**
- Mirroring binaries to our own GitHub Releases (separate Phase 2 change). That workflow will both re-host messy upstreams under clean URLs **and normalize app-bundle layouts** (e.g. rename vim's `vim92/` runtime dir to a fixed name, repackaging as one archive) so the version disappears from every path. After that, those tools become trivial one-line Renovate annotations against our own repo.
- Auto-merging PRs. A human reviews every bump and runs `chezmoi apply`.
- Touching the self-built `statusline` / `passgen` releases.
- Building Renovate custom datasources for jdtls / dos2unix now — that detection logic is throwaway once the mirror workflow owns it.

## Decisions

### D1 — Inline `# renovate:` comments + one regex manager
Annotate each auto-bumpable pin:

```
# renovate: datasource=github-releases depName=starship/starship
{{- $starshipVersion := "1.25.1" }}
```

One custom manager matches `# renovate: …` followed by the next `{{- $…Version := "…" }}` line, capturing `currentValue`; datasource/depName/versioning/extractVersion travel in the comment. Self-documenting, one manager for all tools, adding a future tool is two lines next to the pin. These are TOML `#` comments on their own line, so chezmoi passes them through untouched. Alternative (one `customManagers` block per tool) rejected: ~25 near-duplicate JSON blocks divorced from the pin.

### D2 — Tiers
- **Tier A — auto-bump** via `github-releases` or a dedicated datasource. Clean tag scheme, single `$Version` variable.
- **Tier B — auto-bump, version source ≠ download host.** Annotate with the GitHub/other datasource that tracks the version even though the binary comes from a CDN.
- **Deferred — `# renovate: ignore`.** Upstream detection or layout is messy; defer to the mirror phase. Each carries a one-line reason so the exclusion is intentional and greppable.

### D3 — Per-tool mapping

Tier A (`github-releases`, `depName` = `org/repo`, unless noted):

| Tool | depName | Note |
|------|---------|------|
| rtk | rtk-ai/rtk | |
| starship | starship/starship | |
| zellij | zellij-org/zellij | |
| uv | astral-sh/uv | no `v` prefix |
| jq | jqlang/jq | `extractVersion=^jq-(?<version>.+)$` |
| ripgrep | BurntSushi/ripgrep | var also in archive `path` (consistent) |
| kubelogin | int128/kubelogin | annotate the variable once; shared by 2 externals |
| yt-dlp | yt-dlp/yt-dlp | CalVer → `versioning=loose` |
| hugo | gohugoio/hugo | |
| nexttrace | nxtrace/NTrace-V1 | |
| golangci-lint | golangci/golangci-lint | var also in archive `path` (consistent) |
| gopass | gopasspw/gopass | |
| docker-compose | docker/compose | |
| nvm | coreybutler/nvm-windows | |
| 7zip | ip7z/7zip | `versioning=loose`; asset derived in-template |
| cascadia NF | ryanoasis/nerd-fonts | |
| jetbrains-mono | JetBrains/JetBrainsMono | |
| **go** | — | `datasource=golang-version` |

Tier B:

| Tool | Mapping | Note |
|------|---------|------|
| kubectl | `github-releases depName=kubernetes/kubernetes extractVersion=^v(?<version>.+)$` | binary from dl.k8s.io |
| maven | `datasource=maven depName=org.apache.maven:maven-core` | binary from archive.apache.org; versions match the core artifact |
| docker CLI | `github-releases depName=docker/cli extractVersion=^v(?<version>.+)$` | binary from download.docker.com static; CDN may lag the tag by ~a day (re-run if a fresh PR 404s) |

Deferred to mirror (Phase 2) — `# renovate: ignore — <reason>`:

| Tool | Reason | What the mirror phase will do |
|------|--------|-------------------------------|
| jdtls | Eclipse `snapshots/` milestone+timestamp; old builds pruned. (scoop scrapes `snapshots/latest.txt`.) | re-host a pinned build under a clean URL; optional layout normalize |
| ffmpeg | BtbN dated `autobuild` tag + git-describe asset filename — not derivable from version. chezmoi can't extract GyanD's clean `.7z`. | re-host a `.zip` (or repackage) under a clean, version-named URL |
| dos2unix | waterlander.net HTML page; no off-the-shelf Renovate datasource (Renovate is weak at arbitrary HTML; scoop's free-form `checkver` is not). | re-host under a clean URL |
| vim | Not a detection problem — `vim92` runtime dir name is coupled to MAJOR.MINOR and hardcoded in 15 static `.cmd` wrappers; mirror-side **normalization** (rename `vim92`→fixed, repackage one archive) removes the version from every path. | repackage a normalized archive; wrappers then hardcode a fixed dir forever |

### D4 — JDK refactor
The 5 Temurin entries are currently hardcoded full URLs that encode the version twice with different escaping (`%2B` in the tag, `_` in the asset). Refactor each to a `$jdkNNVersion` variable (value e.g. `21.0.11+10`) and template both encodings:
- tag: `jdk-{{ $v | replace "+" "%2B" }}`
- asset: `…hotspot_{{ $v | replace "+" "_" }}.zip`

Annotate each with `github-releases depName=adoptium/temurinNN-binaries` + an `extractVersion` for the `jdk-` prefix. **Major-locking is free**: each major is a *separate* GitHub repo (`temurin21-binaries` only publishes 21.x), so Renovate cannot cross majors — no `allowedVersions` needed. Verify each refactored entry renders the exact current URL before/after.

### D5 — Renovate enablement & PR hygiene
Hosted Renovate GitHub App (free for this public repo, zero CI, does not consume Actions minutes). `renovate.json` sets `dependencyDashboard: true`, a weekly `schedule`, labels, **no `automerge`**, and `ignoreUnstable`/stability so RC tags (e.g. k8s) aren't proposed.

## Risks / Trade-offs

- **chezmoi renders the file as a template** → a bad annotation could break every apply. Mitigation: `# ` comments on their own lines; verify rendered output identical before/after (JDK entries: verify the rendered URL specifically).
- **Renovate regex misses / mis-captures a pin** → silent no-op or wrong dep. Mitigation: `renovate-config-validator`, then a dry-run / dependency-dashboard listing; reconcile the detected count against the Tier A+B+JDK table.
- **GitHub API rate limits** on the datasource lookups → the hosted app authenticates; supply `GITHUB_TOKEN` only if needed.
- **Pre-release noise** (k8s RCs) → `ignoreUnstable: true` + per-package rules.
- **Shared-variable entries** (kubelogin ×2) — annotate the variable once.
- **(Phase 2, recorded now)** a repackaged/normalized mirror asset is no longer upstream's bytes → we own integrity. Mitigation: record upstream version + checksum in the release notes; keep the transform deterministic and reviewable.

## Migration Plan

1. Add `renovate.json` + Tier A/B annotations + JDK refactor + deferred ignore-comments in one PR.
2. Verify chezmoi render unchanged (JDK: URL identical); run `renovate-config-validator`.
3. Enable the Renovate GitHub App; merge its onboarding PR.
4. Watch the first bump PRs + dashboard; reconcile detected-dep count; fix any missed regex.
5. Rollback = revert the PR / disable the app. No machine changes until a bump PR is merged and `chezmoi apply` runs.

## Open Questions

- Schedule cadence — propose weekly (`before 6am on monday`); easy to tune.
- Phase 2 scope (mirror + normalize) is a separate change; this design only records why the deferred tools land there.
