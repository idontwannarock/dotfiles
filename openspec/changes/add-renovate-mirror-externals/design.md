## Context

Renovate Phase 1 (archived change `2026-06-29-add-renovate-autobump`) auto-bumps 22 of 26 external pins in `home/.chezmoiexternal.toml`. Four tools carried `# renovate: ignore` as "deferred to mirror phase":

| Tool | Original blocker | Resolution |
|------|------------------|------------|
| ffmpeg | Wave 6 used BtbN's dated `autobuild-*` tag; premise was "chezmoi can't extract GyanD's `.7z`" | **Not a mirror case.** GyanD also publishes a clean-semver `.zip`; the versioned internal path is handled by a `path` variable (cf. `golangci-lint`). ffmpeg becomes a direct Renovate pin on `GyanD/codexffmpeg`. |
| vim | `vimXX/` runtime-dir name coupled to MAJOR.MINOR and hardcoded in 15 static `.cmd` wrappers | Mirror: repackage to a stable `current/` dir. |
| jdtls | Eclipse `snapshots/` milestone+timestamp build, pruned over time, no datasource | Mirror: verbatim re-host for durability + checver on `latest.txt`. |
| dos2unix | waterlander.net HTML page, no datasource | Mirror: checver scrape + re-host a stable URL. |

**Root cause (the three real mirror cases):** Renovate needs a clean, parseable version source and chezmoi needs a stable anonymous URL with a version-free on-disk layout; vim/jdtls/dos2unix each fail one of these, so detecting/normalizing must live in our own workflow. Constraints: cross-platform chezmoi repo where the source of truth is git (nothing applies to a machine until `chezmoi apply`); the repo values explicit, reproducible version pins; these tools are Windows-only (externals live inside a `{{ if eq .chezmoi.os "windows" }}` block).

## Goals / Non-Goals

**Goals:**
- Give the last four tools the same automated, reviewable version bumps as the other 22 — ffmpeg via a direct Renovate annotation, vim/jdtls/dos2unix via the mirror workflow.
- Keep explicit version pins (reproducibility) and human-in-the-loop review (no auto-merge, no auto-apply).
- Decouple vim's wrappers from the version permanently.
- Insulate against upstream fragility (Eclipse pruning old snapshots; waterlander being a single personal site).

**Non-Goals:**
- Mirroring the 22 tools Renovate already tracks directly (YAGNI — added indirection with no benefit).
- Migrating self-built `statusline`/`passgen` (already on their own Releases).
- Fixing Git Bash `vim` PATH precedence (pre-existing, unrelated).

## Decisions

### D1: Topology — "workflow full-package" (Option A)
The mirror workflow does everything per tool: detect upstream → repackage → publish to **this repo's own Releases** → open the pin-bump PR itself. The four stay `renovate: ignore`; the workflow drives their bumps.

- **Alternative — Renovate two-stage** (workflow re-hosts; a normal `# renovate:` annotation tracks our mirror release): rejected. Renovate's `github-releases` datasource is per-repo and would conflate mixed tag prefixes (`mirror-ffmpeg-*`, `mirror-vim-*`, `statusline-latest`, …) in one repo, forcing 4 separate mirror repos plus a two-stage bump delay — for the sole benefit of a unified review inbox.
- **Alternative — rolling / no-pin** (fixed `*-latest` tag, version-less URL, chezmoi `refreshPeriod` re-fetches): rejected. Sacrifices reproducibility — every other pin is an explicit version.
- **Rationale:** upstream detection must live in the workflow anyway, so "also open a one-line pin PR" is near-zero marginal cost, adds zero repos, and keeps reproducibility.

### D2: ffmpeg — direct Renovate on GyanD `.zip` (dropped from the mirror)
`ffmpeg.org` ships no official Windows binaries; it links two third-party providers (gyan.dev, BtbN). Scoop's original ffmpeg source is `GyanD/codexffmpeg` (verified from scoop's `main` bucket manifest) — so this is a *return* to the original scoop source; Wave 6's BtbN choice was the departure. GyanD publishes clean semver tags **and a `.zip` asset** (`ffmpeg-<v>-full_build.zip`), which chezmoi handles directly; the versioned internal directory (`ffmpeg-<v>-full_build/bin/…`, confirmed by scoop's `extract_dir`) is resolved with a `path` variable exactly like `golangci-lint`/`gopass`. So ffmpeg needs no re-hosting — it becomes a normal Tier-A pin: `# renovate: datasource=github-releases depName=GyanD/codexffmpeg` (bare tags, no `extractVersion`), bumped by the existing custom manager.

- **Alternative — mirror ffmpeg (repackage `.7z` → `.zip`)**: rejected once the `.zip` asset was found. Mirroring would add a job + script and a second bump stream for zero benefit; ffmpeg has no wrapper coupling (unlike vim), so a versioned internal path is harmless.
- **Discovery note:** the original "chezmoi can't extract GyanD's `.7z`" premise was incomplete — GyanD publishes both `.7z` and `.zip`.

### D3: vim — stable runtime dir + explicit `VIMRUNTIME`
Upstream always names the runtime dir `vimXX` by MAJOR.MINOR, so any direct download re-introduces the version into the path. Only repackaging with a stable name (`current/`) breaks the coupling — hence vim must be mirrored. The 15 wrappers get a one-time edit: reference `current` and `set "VIMRUNTIME=…\vim\current"`.

- **Why explicit `VIMRUNTIME` over relying on vim's auto-detect:** vim derives `$VIMRUNTIME` from the executable path via a heuristic; an explicit env value is first priority in its resolution order, bypassing the heuristic entirely and guaranteeing syntax/help/tutor keep working regardless of dir name. Chosen over the lighter "rename only, trust auto-detect" because a heuristic miss fails silently.

### D4: jdtls & dos2unix — checver parity with scoop, mirror for durability
Neither has a layout problem. jdtls: checver reads `snapshots/latest.txt` (verified single-line filename, e.g. `jdt-language-server-1.61.0-202607061532.tar.gz`); re-host the `.tar.gz` verbatim — the durability win is that Eclipse prunes old snapshots but our mirror never does. dos2unix: checver scrapes waterlander for `Stable version:\s+([\d.]+)` (verified identical to scoop's manifest); extract the single `.exe`, simplify external `archive-file` → `file`.

### D5: Workflow mechanics
- **Runner `ubuntu-latest`**: mirroring is pure file manipulation (extract → rename/pick → repackage); the Windows `.exe`s are never executed, so no Windows runner. Uses only preinstalled `unzip`/`zip`/`curl`/`gh` (no `.7z` handling — ffmpeg, the only `.7z` case, left the mirror).
- **Schedule**: weekly Monday (after Renovate's `before 6am on monday`) + `workflow_dispatch`.
- **Naming**: tag `mirror-<tool>-<v>`; assets `mirror-vim-<v>.zip` / `jdt-language-server-<v>.tar.gz` (verbatim) / `dos2unix-<v>.exe`.
- **Release notes**: upstream source URL + upstream version + sha256 of the upstream file (provenance for repackaged bytes).
- **Idempotency**: each job checks `gh release view mirror-<tool>-<v>`; skip publish + PR if it exists; skip the whole job if the pin already equals the new version.
- **PR**: branch `mirror/<tool>-<v>` → edit the version variable → `gh pr create` with `dependencies` label, body stating old→new + upstream link. One PR per tool. No auto-merge.
- **Permissions**: `GITHUB_TOKEN` with `contents: write` + `pull-requests: write`; repo setting "Allow GitHub Actions to create and approve pull requests" enabled.

## Risks / Trade-offs

- HTML/text checver for jdtls (`latest.txt`) and dos2unix (waterlander) is inherently more brittle than an API → **Mitigation:** the scrape runs in our workflow, so a format change makes the job **fail loudly** (red run) rather than silently installing a wrong version; scoop has relied on both for years.
- ffmpeg switches provider BtbN → GyanD → **Mitigation:** both are full/GPL static builds; day-to-day ffmpeg/ffprobe use is unaffected, and GyanD is the ffmpeg.org-endorsed provider + original scoop source. ffmpeg now rides the existing Renovate manager, not the mirror.
- vim wrapper edit touches 15 files at once → **Mitigation:** one-time change; verify on the real machine (incl. SSH) that syntax/help/tutor load before merging. After this, version bumps never touch the wrappers.
- Two bump-PR streams (Renovate for 22, our workflow for 4) → **Mitigation:** both carry the `dependencies` label; the split is intentional and documented in `docs/renovate.md`.
- Actions needs write permissions (release + PR) → **Mitigation:** scope `GITHUB_TOKEN` to exactly `contents: write` + `pull-requests: write`; no third-party PAT.

## Migration Plan

1. **ffmpeg (independent, no seeding):** repoint the 3 ffmpeg entries at GyanD's `.zip`, collapse to `$ffmpegVersion`, add the GyanD annotation. Verify render-diff + `ffmpeg -version` on the machine.
2. Land the mirror workflow + per-tool scripts (vim/jdtls/dos2unix); run it once via `workflow_dispatch` to seed the initial `mirror-*` releases from the currently-pinned versions.
3. Repoint the three mirrored externals at the seeded releases; reword the `ignore` comments; do the one-time vim wrapper edit.
4. Verify `chezmoi apply` render-diff is unchanged in effect and, on the real machine (normal shell + SSH), that vim runtime resolves.
5. First live bump candidate proves the loop end-to-end: jdtls `1.59.0` → `1.61.0-202607061532`.

**Rollback:** revert the externals commit (URLs point back at upstream); the `mirror-*` releases can remain (harmless) or be deleted.
