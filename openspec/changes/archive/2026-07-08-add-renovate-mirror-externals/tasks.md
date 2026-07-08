## 1. Repo prerequisites

- [ ] 1.1 In the GitHub repo settings, enable "Allow GitHub Actions to create and approve pull requests"; confirm the workflow scopes `GITHUB_TOKEN` to `contents: write` + `pull-requests: write`

## 2. ffmpeg → direct Renovate (independent of the mirror, no seeding)

- [x] 2.1 Repoint the 3 ffmpeg entries in `home/.chezmoiexternal.toml` at GyanD's `.zip`: collapse `$ffmpegTag`+`$ffmpegAsset`+`$ffmpegRoot` into a single `$ffmpegVersion`, `url = …/GyanD/codexffmpeg/releases/download/{{ $ffmpegVersion }}/ffmpeg-{{ $ffmpegVersion }}-full_build.zip`, `path = ffmpeg-{{ $ffmpegVersion }}-full_build/bin/<exe>`, and replace the `# renovate: ignore` line with `# renovate: datasource=github-releases depName=GyanD/codexffmpeg`
- [x] 2.2 Verify: chezmoi render-diff shows only the intended ffmpeg change; after `chezmoi apply`, `ffmpeg -version` and `ffprobe -version` work

## 3. Mirror workflow and per-tool scripts (vim, jdtls, dos2unix)

- [x] 3.1 Add `.github/scripts/mirror-vim.sh`: checver latest `vim/vim-win32-installer` tag → download `gvim_<v>_x64.zip` → drop top-level `vim/`, rename `vimXX/` → `current/` → rezip rooted at `current/` as `mirror-vim-<v>.zip`
- [x] 3.2 Add `.github/scripts/mirror-jdtls.sh`: checver `snapshots/latest.txt` → download the `.tar.gz` and re-host it verbatim as `jdt-language-server-<v>.tar.gz`
- [x] 3.3 Add `.github/scripts/mirror-dos2unix.sh`: checver scrape waterlander for `Stable version:\s+([\d.]+)` → download win64 zip → extract single `bin/dos2unix.exe` as `dos2unix-<v>.exe`
- [x] 3.4 Add a shared step/script for: sha256 of the upstream file, `gh release view` idempotency check, `gh release create` with provenance notes (upstream URL + version + sha256), and the pin-bump PR (branch `mirror/<tool>-<v>`, edit the version variable, `gh pr create --label dependencies`, no auto-merge)
- [x] 3.5 Add `.github/workflows/mirror-externals.yml`: `ubuntu-latest`, `schedule` weekly Monday + `workflow_dispatch`, one job per tool (vim, jdtls, dos2unix) wiring 3.1–3.4, `permissions: contents: write, pull-requests: write` (uses only preinstalled `unzip`/`zip`/`curl`/`gh` — no extra apt packages)

## 4. Seed initial mirror releases

- [x] 4.1 Push the branch and run the workflow via `workflow_dispatch`; confirm three releases `mirror-{vim,jdtls,dos2unix}-<current-pin>` are created at the currently-pinned versions
- [x] 4.2 Verify each seeded release's notes record the upstream source URL, upstream version, and upstream-file sha256

## 5. Repoint the mirrored externals and decouple vim wrappers

- [x] 5.1 jdtls: point the external URL at `mirror-jdtls-<v>` (`jdt-language-server-<v>.tar.gz`), reword the `# renovate: ignore` comment to "mirrored by mirror-externals.yml"
- [x] 5.2 dos2unix: change `type = "archive-file"` → `type = "file"`, point the URL at `mirror-dos2unix-<v>` (`dos2unix-<v>.exe`), reword the ignore comment
- [x] 5.3 vim: point the external URL at `mirror-vim-<v>.zip`, drop `stripComponents` (mirror zip is rooted at `current/`), keep `type = "archive"` so it extracts to `.local/share/vim/current/…`, reword the ignore comment
- [x] 5.4 Edit the 15 `.cmd` wrappers in `home/dot_local/bin/` (`vim vi view ex evim eview rvim rview gvim gview gvimdiff rgvim rgview vimdiff xxd`): replace `vim92` with `current` and add `set "VIMRUNTIME=%USERPROFILE%\.local\share\vim\current"`
- [x] 5.5 Confirm no remaining FUNCTIONAL `vim92` coupling (the 15 wrappers are decoupled); historical `vim92` mentions survive only in `run_once_*` script comments, left intact so their hash does not change and re-trigger the migration scripts
- [x] 5.6 Prune stale version files the migration orphans: add `.local/share/vim/vim92` to `home/.chezmoiremove` (one-time; the dir is now the stable `current/`); add `exact = true` to the jdtls external so its version-named jars are pruned on every bump (verified `config_win/` is pristine, so exact is safe)

## 6. Verification

- [x] 6.1 chezmoi render-diff (before/after) of `home/.chezmoiexternal.toml`: every effective change is intended (ffmpeg → GyanD; the three URLs → mirror releases; deployed binaries equivalent)
- [x] 6.2 `chezmoi apply` on this machine; `dos2unix --version` and `jdtls` launch work
- [ ] 6.3 vim: `:syntax`, `:help`, and `:Tutor` load correctly under a normal shell AND an SSH session (VIMRUNTIME resolution intact)
- [ ] 6.4 `npx --yes -p renovate renovate-config-validator renovate.json` passes; ffmpeg is now extracted by the custom manager, and vim/jdtls/dos2unix remain Renovate-ignored (no bump PR)
- [x] 6.5 End-to-end proof: the workflow opens a jdtls bump PR (`1.59.0-202605111959` → `1.61.0-202607061532`) editing only the pin

## 7. Documentation

- [x] 7.1 Update `docs/renovate.md`: move ffmpeg into the tracked tiers (GyanD); move vim/jdtls/dos2unix out of the "Intentionally not tracked" table into a documented mirror-phase section describing the workflow, tag scheme, and the two bump-PR streams
