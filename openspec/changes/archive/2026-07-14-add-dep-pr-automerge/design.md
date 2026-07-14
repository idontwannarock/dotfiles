# Design — add-dep-pr-automerge

## Context

Two independent PR sources bump external tool pins: Renovate (its own app token) and
the mirror workflow (vim/jdtls/dos2unix/gnupg, using `GITHUB_TOKEN`). Today neither
PR is validated by CI and both are merged by hand. The user chose **Option A**:
a single required status check gates every merge to `main`, and safe bumps auto-merge.

Two GitHub mechanics drive the design:
- **Required check + path filter = stuck PR.** A required status check that never
  reports (because a `paths:`-filtered workflow didn't run) blocks the PR forever.
- **`GITHUB_TOKEN` events don't trigger workflows.** A PR created by the mirror job's
  default token would never trigger `validate-externals`, so its required check would
  never report → auto-merge would stall.

## Goals / Non-Goals

**Goals**
- One stable required check on `main` that validates the real failure modes (dead URL,
  broken render, wrong gnupg SHA) and never blocks unrelated PRs.
- Auto-merge `patch`/`minor`/`pin`; keep `major` manual.
- Both PR sources (Renovate + mirror) flow through the same check + auto-merge.

**Non-Goals**
- Runtime testing of the bumped tool (not practical in CI; the `chezmoi apply` gate +
  release-age cool-off cover the residual risk).
- Removing the manual `chezmoi apply` deploy step — unchanged.

## Decisions

### D1 — always-run gate job (fixes stuck-PR)
`validate-externals.yml` triggers on `pull_request` to `main` with **no** `paths:`
filter. Jobs:
- `changes` (always runs): `git diff --name-only <base>...<head>` → output
  `relevant=true` iff `home/.chezmoiexternal.toml` or
  `home/run_onchange_install-gnupg.ps1.tmpl` changed.
- `render` (matrix ubuntu/macos/windows, `if: relevant`): install chezmoi,
  `chezmoi execute-template < home/.chezmoiexternal.toml` (chezmoi fills `.chezmoi.os`
  /`.chezmoi.arch` from the runner, so each OS renders its own URL set), extract
  `url = "..."`, HEAD-check each (`curl -fsSIL` → success + non-empty).
- `gnupg` (`if: relevant`): parse the three `$gpg*` vars, build the gnupg.org URL,
  download, `sha256sum` vs the pin.
- `gate` (`needs: [changes, render, gnupg]`, `if: always()`): the **single required
  check**. Passes when `relevant=false`, or when the needed jobs all succeeded; fails
  if any required job failed. Requiring `gate` (not the matrix legs) keeps the
  branch-protection check name stable and always-reported.

### D2 — mirror PRs via PAT (fixes no-trigger)
`mirror-externals.yml` checks out with `token: ${{ secrets.MIRROR_PAT }}` so the
persisted git creds AND `gh` act as the PAT identity; its PRs then trigger
`validate-externals`. After `gh pr create`, the scripts run
`gh pr merge --auto --squash --delete-branch "$branch"` to enable GitHub auto-merge
(waits for the required gate). This replaces the "never auto-applied" behavior. The
change touches `open_bump_pr` (common) and `mirror-gnupg.sh`; the added line is a
single `gh pr merge --auto` after the existing create.

### D3 — Renovate config
Add packageRules: `{ matchUpdateTypes: ["patch","minor","pin"], automerge: true }`
and keep `major` non-automerge (default). Set `platformAutomerge: true` (GitHub native
auto-merge, gated on the required check) and `minimumReleaseAge: "3 days"` (blocks a
yanked/hotfixed release for free). Renovate's app-token PRs already trigger workflows,
so no PAT is needed on that side.

### D4 — manual prerequisites (documented, not code)
One-time repo setup, recorded in `docs/renovate.md`:
1. Settings → General → "Allow auto-merge" ON.
2. Branch protection (or ruleset) on `main`: require the `gate` status check.
3. Create a fine-grained PAT (this repo; Contents: RW, Pull requests: RW) and store as
   the `MIRROR_PAT` secret. Note its expiry — if it lapses, mirror PRs stop triggering
   the check and their auto-merge stalls (they won't mis-merge, just wait).

## Risks / Trade-offs

- **PAT expiry stalls mirror auto-merge.** Fail-safe (PRs wait, never mis-merge);
  mitigation is a calendar note. Documented in D4.
- **`chezmoi execute-template` availability per-OS.** chezmoi has first-party installers
  for all three runners; if the render step can't run, the `render` job fails → gate
  fails → no bad merge (fail-closed).
- **HEAD request refused by a host** (some CDNs reject HEAD). Use `curl -fsSIL`; if a
  known host rejects HEAD, fall back to a ranged GET (`-r 0-0`). Handle during impl.
- **Auto-merging a bad-but-downloadable version** (URL 200, tool broken at runtime).
  Residual; covered by `minimumReleaseAge`, `major`-manual, and the `chezmoi apply`
  gate where the install script re-verifies.

## Migration

None for machines. First effect: the next Renovate patch/minor PR (and mirror PRs)
auto-merge once green instead of waiting for a manual click. Existing open PRs (#4–#7)
are unaffected unless rebased.
