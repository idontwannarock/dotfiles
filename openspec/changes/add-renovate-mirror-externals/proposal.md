## Why

Renovate Phase 1 auto-bumps 22 of 26 external tool pins, but four (ffmpeg, vim, jdtls, dos2unix) were explicitly deferred to a "mirror phase" because their upstreams were thought untrackable by any Renovate datasource. On closer inspection ffmpeg is directly trackable (GyanD publishes a clean-semver `.zip`), so it rejoins the Renovate-tracked set; the remaining three genuinely need re-hosting/layout-normalization. This change builds a mirror workflow for those three and folds ffmpeg into Phase 1's annotation model, so all 26 tools get automated, reviewable version bumps.

## What Changes

- **ffmpeg → direct Renovate (no mirror):** repoint the 3 ffmpeg entries at GyanD's `.zip` (`GyanD/codexffmpeg`, scoop's original source, ffmpeg.org-endorsed), using a versioned internal `path` variable like `golangci-lint`; collapse the `$ffmpegTag`+`$ffmpegAsset` double variable into one `$ffmpegVersion`; add a normal `# renovate: datasource=github-releases depName=GyanD/codexffmpeg` annotation. The existing custom manager bumps it.
- Add `.github/workflows/mirror-externals.yml`: a scheduled (weekly, Monday) + manually-dispatchable GitHub Actions workflow with one job per **mirrored** tool (vim, jdtls, dos2unix) that detects the latest upstream version, repackages/normalizes it, publishes it to this repo's own GitHub Releases under a version-bearing `mirror-<tool>-<version>` tag, and opens a one-per-tool pin-bump PR against `home/.chezmoiexternal.toml`.
- Repoint the three mirrored externals' URLs at our mirror releases:
  - **vim**: repackage renaming the versioned `vimXX/` runtime dir to a stable `current/`; one-time edit of the 15 `.cmd` wrappers to reference `current` and set `VIMRUNTIME` explicitly, decoupling them from the version forever.
  - **jdtls**: verbatim re-host of the upstream `.tar.gz` (durability against Eclipse snapshot pruning).
  - **dos2unix**: extract the single `dos2unix.exe`, simplify the external from `archive-file` to `file`.
- Reword the three mirrored tools' `# renovate: ignore` comments from "deferred to mirror phase" to "mirrored by mirror-externals.yml"; they stay ignored by Renovate (the mirror workflow drives their bumps, not Renovate).
- Update `docs/renovate.md`: move ffmpeg into the tracked tiers; move the three out of the "Intentionally not tracked" table into a documented mirror-phase section.

## Capabilities

### New Capabilities
- `external-tool-mirroring`: a GitHub Actions workflow that re-hosts and layout-normalizes the three upstream tools Renovate cannot track directly (vim, jdtls, dos2unix), publishing them to this repo's Releases and opening reviewable pin-bump PRs — without auto-merge and without changing what `chezmoi apply` deploys until the PR is merged.

### Modified Capabilities
- `external-version-automation`: the "Messy-upstream tools are explicitly deferred" requirement changes — ffmpeg is no longer deferred (it becomes a normal GyanD-annotated Renovate pin), and vim/jdtls/dos2unix are no longer merely deferred but mirrored by the new workflow (reworded `# renovate: ignore`, externals pointing at our mirror releases, same deployed binaries).

## Impact

- **New file**: `.github/workflows/mirror-externals.yml` (+ per-tool helper scripts under `.github/`).
- **Modified**: `home/.chezmoiexternal.toml` (ffmpeg repointed to GyanD + annotated; 3 mirrored externals repointed), `home/dot_local/bin/*.cmd` (15 vim wrappers), `docs/renovate.md`.
- **New GitHub Releases**: `mirror-vim-*`, `mirror-jdtls-*`, `mirror-dos2unix-*` in `idontwannarock/dotfiles`.
- **Repo settings**: Actions needs `contents: write` + `pull-requests: write`, and "Allow GitHub Actions to create and approve pull requests" enabled.
- **Renovate config** unchanged in structure — ffmpeg now matches the existing custom manager (one more tracked pin, 23 total); vim/jdtls/dos2unix stay ignored; no change to the other 22 tools.
