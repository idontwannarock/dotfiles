## MODIFIED Requirements

### Requirement: Bumps arrive as reviewable PRs, never auto-applied
A job SHALL, when it mirrors (or, for gnupg, detects) a version newer than the current
pin, open a pull request that edits only that tool's pin, labelled `dependencies`,
one PR per tool. To let the PR pass through the same `validate-externals` required
check as Renovate's PRs, the mirror workflow SHALL create these PRs using a personal
access token (`MIRROR_PAT`) rather than the default `GITHUB_TOKEN` (whose events do
not trigger further workflows). Each PR SHALL enable GitHub auto-merge with squash so
it merges once the validate check passes. The job SHALL NOT merge the PR directly
without the check. Deployment to a machine SHALL still require a manual `chezmoi apply`
after merge.

#### Scenario: A newer mirror opens a pin PR that auto-merges on green
- **WHEN** a job publishes a mirror release (or gnupg detects a new version) whose version differs from the pin
- **THEN** it opens a `dependencies`-labelled PR via `MIRROR_PAT` and enables squash auto-merge, which completes only after `validate-externals` succeeds

#### Scenario: Up-to-date pin opens no PR
- **WHEN** the current pin already equals the newest mirrored/detected version
- **THEN** the job opens no PR

#### Scenario: The PR triggers the validate check
- **WHEN** the mirror PR is created
- **THEN** because it was created with `MIRROR_PAT`, the `validate-externals` workflow runs on it (a `GITHUB_TOKEN`-created PR would not trigger it)
