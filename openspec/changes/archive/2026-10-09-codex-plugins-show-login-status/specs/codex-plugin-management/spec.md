## MODIFIED Requirements

### Requirement: chezmoi SHALL reconcile required Codex plugins

The chezmoi source SHALL provide platform-specific `run_` installers that ensure the `slack` plugin is installed and enabled after the Codex CLI becomes available. The installers SHALL identify the plugin by its `name` field, because the marketplace that qualifies the reported `pluginId` differs per machine. The installers SHALL add the plugin as `slack@openai-curated`. The installers SHALL use the Codex plugin CLI rather than writing plugin cache or marketplace state directly.

#### Scenario: Slack plugin is missing
- **WHEN** `chezmoi apply` runs, Codex is available, and `codex plugin list --json` reports no entry named `slack` that is installed and enabled
- **THEN** the installer runs `codex plugin add slack@openai-curated --json`

#### Scenario: Slack plugin is already installed and enabled
- **WHEN** `chezmoi apply` runs and `codex plugin list --json` reports an entry named `slack` as installed and enabled
- **THEN** the installer logs a skip and SHALL NOT reinstall the plugin
- **AND** the skip holds whatever marketplace qualifies that entry's `pluginId`

#### Scenario: Slack plugin is installed but disabled
- **WHEN** `chezmoi apply` runs and the `slack` plugin is installed but not enabled
- **THEN** the installer invokes the Codex plugin add operation to restore the required enabled state

#### Scenario: Codex is temporarily unavailable
- **WHEN** the installer runs and the `codex` command is unavailable
- **THEN** the installer logs a warning and exits successfully without attempting plugin installation
- **AND** the installer runs again on the next `chezmoi apply`

#### Scenario: Codex is not logged in
- **WHEN** the installer runs, the `codex` command is available, and `codex login status` exits nonzero
- **THEN** the installer logs a warning that tells the user to run `codex login`
- **AND** the warning includes the output of `codex login status`, so a failure with another cause stays visible
- **AND** the installer exits successfully without listing or adding plugins
- **AND** the installer runs again on the next `chezmoi apply`

#### Scenario: Plugin inspection or installation fails
- **WHEN** Codex is logged in, and Codex returns invalid plugin-list JSON or the plugin add operation exits nonzero
- **THEN** the installer exits nonzero and the shared closing banner reports failure

