## 1. gnupg detector script

- [x] 1.1 Create `.github/scripts/mirror-gnupg.sh`: shebang, `set -euo pipefail`, `cd` to repo toplevel, source `mirror-common.sh` (for `log` + `validate_version` only).
- [x] 1.2 Honor seed mode: if `PUBLISH_ONLY=true`, `log` a skip note and exit 0 (gnupg is never re-hosted).
- [x] 1.3 Scrape version + date from `https://www.gnupg.org/download/index.html` with regex `gnupg-w32-([0-9.]+)_([0-9]+)\.exe`; empty → `log` + exit 1. Run `validate_version` on the version.
- [x] 1.4 Scrape SHA-256 from `https://www.gnupg.org/download/integrity_check.html`: match the line `^[0-9a-f]{64}  gnupg-w32-<ver>_<date>\.exe$`; guard the result with `^[0-9a-f]{64}$`; no match → `log` + exit 1.
- [x] 1.5 Read the current pin: `current_gpg_pin` reads `$gpgVersion` from `home/run_onchange_install-gnupg.ps1.tmpl` via `sed`. If unreadable → `log` + skip PR.
- [x] 1.6 Up-to-date check: if detected version == current `$gpgVersion`, `log` "already at" + exit 0 (no PR).
- [x] 1.7 Bump + PR: branch `mirror/gnupg-<ver>`; guard on an already-open PR for that branch (recover-on-rerun); three `sed -i` edits for `$gpgVersion`/`$gpgDate`/`$gpgSha256`; commit as `chore(deps): bump gnupg <cur> -> <ver>`; `git push --force`; ensure `dependencies` label; `gh pr create` with a body noting no re-host + manual `chezmoi apply`.

## 2. Wire into the workflow

- [x] 2.1 Add `gnupg` to the `strategy.matrix.tool` list in `.github/workflows/mirror-externals.yml`.
- [x] 2.2 Update the workflow header comment to note gnupg is detect-only (no re-host; gnupg.org URLs are durable).

## 3. Comment fix

- [x] 3.1 In `home/.chezmoiexternal.toml` (~L165), correct the stale `gpg suite stays on scoop` comment to reflect Wave 8 (`gpg-off-scoop`): gpg is provisioned by `run_onchange_install-gnupg.ps1.tmpl` from the gnupg.org NSIS, not scoop.

## 4. Verify

- [x] 4.1 `bash -n .github/scripts/mirror-gnupg.sh` (syntax) and `shellcheck` if available.
- [x] 4.2 Dry-run the scrape logic locally (curl both pages, confirm it extracts `2.5.21` / `20260702` / the 64-hex SHA-256 `6246c925...`, and that the up-to-date/bump branches behave). Do NOT push a real PR from local.
- [x] 4.3 `openspec validate add-gnupg-checkver --strict`.
- [ ] 4.4 After merge to main, trigger `workflow_dispatch` once and confirm the gnupg job opens the 2.5.20 → 2.5.21 bump PR (real end-to-end check).
