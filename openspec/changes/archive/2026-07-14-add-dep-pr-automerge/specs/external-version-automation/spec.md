## MODIFIED Requirements

### Requirement: Updates go through human review
Renovate SHALL auto-merge low-risk update types and reserve human review for risky
ones. `patch`, `minor`, and `pin` updates SHALL be configured to auto-merge **only
after** the `validate-externals` CI check passes, using GitHub's native auto-merge
(`platformAutomerge`), and SHALL respect a `minimumReleaseAge` cool-off before a bump
is opened. `major` updates SHALL NOT auto-merge — they remain manual pull requests.
Deployment to a machine SHALL still require a manual `chezmoi apply`, so auto-merge
to `main` never changes a machine on its own. The self-built `statusline` and
`passgen` release pins SHALL remain excluded from Renovate.

#### Scenario: A patch/minor bump auto-merges after the check passes
- **WHEN** Renovate opens a `patch` or `minor` bump PR and the `validate-externals` check succeeds
- **THEN** GitHub auto-merges (squashes) the PR without human action, and no machine changes until `chezmoi apply` is run

#### Scenario: A major bump waits for a human
- **WHEN** Renovate opens a `major` bump PR
- **THEN** it is not auto-merged; it stays open for manual review and merge

#### Scenario: A bump that fails validation does not merge
- **WHEN** a bump PR's `validate-externals` check fails (e.g. the new URL 404s)
- **THEN** auto-merge does not proceed and the PR stays open

#### Scenario: Self-built tools are not tracked
- **WHEN** Renovate scans the externals file
- **THEN** the `statusline` and `passgen` entries receive no bump annotation and no PR

## ADDED Requirements

### Requirement: External bump PRs are validated by a required CI check
The repository SHALL contain a workflow `.github/workflows/validate-externals.yml`
that runs on every pull request to `main` and reports a single stable status check
(the branch-protection required check). To avoid blocking unrelated PRs, the workflow
SHALL use an always-run gate: it SHALL detect whether the PR changed
`home/.chezmoiexternal.toml` or `home/run_onchange_install-gnupg.ps1.tmpl`, and if
neither changed the gate SHALL report success immediately without running the
validation steps. When a relevant file changed, the workflow SHALL, on each of
ubuntu/macos/windows, render `home/.chezmoiexternal.toml` with chezmoi and confirm
every rendered download `url` resolves (HTTP success, non-empty), and SHALL verify
that gnupg's pinned `$gpgVersion`/`$gpgDate`/`$gpgSha256` produce a download whose
SHA-256 matches the pin. Any failure SHALL fail the required check.

#### Scenario: An unrelated PR passes the gate instantly
- **WHEN** a PR that touches neither the externals file nor the gnupg script is opened against `main`
- **THEN** the `validate-externals` gate reports success without running the render/URL/SHA steps, so the PR is not blocked

#### Scenario: A bump with a dead URL fails the gate
- **WHEN** a PR bumps a pin to a version whose download URL returns a non-success status on any OS
- **THEN** the render/URL step fails and the required gate check fails

#### Scenario: A wrong gnupg SHA fails the gate
- **WHEN** a PR changes the gnupg pin such that the downloaded installer's SHA-256 does not match `$gpgSha256`
- **THEN** the gnupg verification step fails and the required gate check fails
