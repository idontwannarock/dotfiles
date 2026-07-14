## Why

Dependency bump PRs (Renovate's ~23 pins + the mirror workflow's vim/jdtls/dos2unix/gnupg)
currently merge with **no automated validation** — there is no CI on a bump PR, so
"reviewing" one is guesswork: the reviewer can't practically confirm the new tool
works, only that the new version downloads. That manual gate is friction with
little payoff, and it delays low-risk patch/minor bumps.

The realistic failure mode of a bump is narrow and checkable: the new download URL
404s (renamed asset / bad version string), the template stops rendering, or (gnupg)
the pinned SHA-256 doesn't match the real file. Everything else is caught by the
existing manual `chezmoi apply` gate — merging to main never changes a machine.

## What Changes

- Add `.github/workflows/validate-externals.yml`: a required status check that, on
  any PR touching the externals config or the gnupg install script, renders the
  externals per-OS (ubuntu/macos/windows) and HEAD-checks every download URL, and
  verifies gnupg's pinned SHA-256 against the real file. It uses an **always-run +
  internal-skip** shape so unrelated PRs report an instant green (no stuck-PR).
- Turn on Renovate **auto-merge** for `patch`/`minor`/`pin` updates (via GitHub
  native auto-merge, gated on the validate check), with a `minimumReleaseAge` cool-off;
  **major** updates stay manual.
- Make the mirror PRs auto-merge on a green check: create them with a PAT (so they
  trigger the validate check) and `gh pr merge --auto --squash`.
- Document the one-time manual prerequisites (enable "Allow auto-merge", require the
  validate check in branch protection, create the `MIRROR_PAT` secret).

Machines still only change on a manual `chezmoi apply` — auto-merge to main is
low-stakes.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `external-version-automation`: Renovate is no longer "no auto-merge" — safe update
  types auto-merge after passing a new CI validation check; major stays manual. Adds
  the validation-check requirement.
- `external-tool-mirroring`: mirror bump PRs are no longer "never auto-applied" — they
  are created via a PAT and auto-merge once the validate check passes (deploy still
  needs `chezmoi apply`).

## Impact

- **New workflow:** `.github/workflows/validate-externals.yml`.
- **Config:** `renovate.json` — packageRules for automerge by update type,
  `platformAutomerge`, `minimumReleaseAge`.
- **Workflow + scripts:** `.github/workflows/mirror-externals.yml` (checkout with
  `MIRROR_PAT`), `.github/scripts/mirror-common.sh` + `.github/scripts/mirror-gnupg.sh`
  (auto-merge the opened PR).
- **Docs:** `docs/renovate.md` — auto-merge behavior + manual prerequisites.
- **Manual, one-time (not code):** repo "Allow auto-merge" on; branch protection on
  `main` requiring the validate gate check; fine-grained PAT stored as `MIRROR_PAT`.
- No machine-facing behavior change; the `chezmoi apply` deploy gate is unchanged.
