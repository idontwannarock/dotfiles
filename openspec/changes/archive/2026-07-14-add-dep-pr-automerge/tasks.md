## 1. validate-externals workflow

- [x] 1.1 Create `.github/workflows/validate-externals.yml`, `on: pull_request` to `main`, no `paths:` filter. `permissions: contents: read`.
- [x] 1.2 Job `changes` (always runs): compute `git diff --name-only origin/${{ github.base_ref }}...HEAD`, set output `relevant=true` iff `home/.chezmoiexternal.toml` or `home/run_onchange_install-gnupg.ps1.tmpl` is in the list. (checkout with `fetch-depth: 0` for the diff base.)
- [x] 1.3 Job `render` (matrix ubuntu/macos/windows, `if: needs.changes.outputs.relevant == 'true'`): install chezmoi; `chezmoi execute-template < home/.chezmoiexternal.toml`; extract `url = "..."` values; HEAD-check each with `curl -fsSIL` (fail on non-success/empty). Handle HEAD-hostile hosts with a ranged GET fallback.
- [x] 1.4 Job `gnupg` (`if: relevant`): parse `$gpgVersion`/`$gpgDate`/`$gpgSha256` from the install script; build `https://www.gnupg.org/ftp/gcrypt/binary/gnupg-w32-<ver>_<date>.exe`; download; `sha256sum` and compare (case-insensitive) to the pin.
- [x] 1.5 Job `gate` (`needs: [changes, render, gnupg]`, `if: always()`): succeed if `relevant=false`; else fail if any needed job's result is `failure`/`cancelled`, otherwise succeed. This is the single required check.

## 2. Renovate auto-merge config

- [x] 2.1 In `renovate.json`, add a packageRule `{ matchUpdateTypes: ["patch","minor","pin"], automerge: true }` and (explicit) `{ matchUpdateTypes: ["major"], automerge: false }`.
- [x] 2.2 Add top-level `"platformAutomerge": true` and `"minimumReleaseAge": "3 days"`.
- [x] 2.3 Validate: `npx --yes -p renovate renovate-config-validator renovate.json`.

## 3. Mirror PRs: PAT + auto-merge

- [x] 3.1 In `.github/workflows/mirror-externals.yml`, set `actions/checkout@v4` `with: token: ${{ secrets.MIRROR_PAT }}`, and pass `GH_TOKEN: ${{ secrets.MIRROR_PAT }}` to the step so the PR is created by the PAT identity (triggers validate-externals).
- [x] 3.2 In `.github/scripts/mirror-common.sh` `open_bump_pr`, after `gh pr create`, run `gh pr merge --auto --squash --delete-branch "$branch"`.
- [x] 3.3 In `.github/scripts/mirror-gnupg.sh`, after `gh pr create`, run the same `gh pr merge --auto --squash --delete-branch "$branch"`.

## 4. Docs

- [x] 4.1 In `docs/renovate.md`, add an "Auto-merge" section: what auto-merges (patch/minor/pin after the check, major manual), the validate-externals gate, and the machine-safety note (chezmoi apply gate).
- [x] 4.2 Document the one-time manual prerequisites: enable "Allow auto-merge", require the `gate` check in branch protection, create the `MIRROR_PAT` fine-grained secret (+ expiry caveat).

## 5. Verify

- [x] 5.1 `actionlint` (if available) + YAML sanity on both workflows; `bash -n` the edited scripts.
- [x] 5.2 Locally dry-run the render+URL logic for one OS: install/execute chezmoi on `.chezmoiexternal.toml`, extract URLs, HEAD-check a sample — confirm it flags a deliberately-broken URL and passes real ones.
- [x] 5.3 `openspec validate add-dep-pr-automerge --strict`.
- [ ] 5.4 Post-merge (needs main + the manual prereqs): confirm the gate check runs on a bump PR, an unrelated PR gets an instant green gate, and a patch/minor PR auto-merges. (Documented as the real end-to-end check; depends on user completing the manual prereqs.)
