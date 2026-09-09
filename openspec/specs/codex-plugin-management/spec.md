# codex-plugin-management Specification

## Purpose
定義 chezmoi 如何跨平台安裝並保留必要的 Codex plugins，同時讓 plugin 自己管理每台機器的帳號連線。

## Requirements

### Requirement: chezmoi SHALL reconcile required Codex plugins

The chezmoi source SHALL provide platform-specific `run_` installers that ensure `slack@openai-curated` is installed and enabled after the Codex CLI becomes available. The installers SHALL use the Codex plugin CLI rather than writing plugin cache or marketplace state directly.

#### Scenario: Slack plugin is missing
- **WHEN** `chezmoi apply` runs, Codex is available, and `codex plugin list --json` does not report `slack@openai-curated` as installed and enabled
- **THEN** the installer runs `codex plugin add slack@openai-curated --json`

#### Scenario: Slack plugin is already installed and enabled
- **WHEN** `chezmoi apply` runs and `codex plugin list --json` reports `slack@openai-curated` as installed and enabled
- **THEN** the installer logs a skip and SHALL NOT reinstall the plugin

#### Scenario: Slack plugin is installed but disabled
- **WHEN** `chezmoi apply` runs and `slack@openai-curated` is installed but not enabled
- **THEN** the installer invokes the Codex plugin add operation to restore the required enabled state

#### Scenario: Codex is temporarily unavailable
- **WHEN** the installer runs and the `codex` command is unavailable
- **THEN** the installer logs a warning and exits successfully without attempting plugin installation
- **AND** the installer runs again on the next `chezmoi apply`

#### Scenario: Plugin inspection or installation fails
- **WHEN** Codex returns invalid plugin-list JSON or the plugin add operation exits nonzero
- **THEN** the installer exits nonzero and the shared closing banner reports failure

### Requirement: Codex plugin reconciliation SHALL behave consistently across platforms

The Unix/macOS/WSL and Windows installers SHALL reconcile the same plugin identifier with the same installed-and-enabled condition. Both installers SHALL follow the repository's shared logging contract and SHALL run after the npm-tools installer that provides Codex.

#### Scenario: Platform templates declare the same required plugin
- **WHEN** the bash and PowerShell installer sources are compared
- **THEN** both identify `slack@openai-curated` as the required plugin

#### Scenario: Installer order follows the Codex CLI installation
- **WHEN** chezmoi orders the rendered install scripts by filename
- **THEN** `run_install-04-codex-plugins` runs after `run_install-02-npm-tools`

#### Scenario: Platform guard selects one installer
- **WHEN** chezmoi renders the templates for a supported operating system
- **THEN** only the installer for that operating system emits executable content

### Requirement: Slack SHALL use the curated plugin connection only

The managed Codex configuration SHALL NOT declare a direct `[mcp_servers.slack]` entry. Slack access SHALL come from `slack@openai-curated`, so Codex does not attempt unsupported dynamic OAuth client registration for a duplicate direct server.

#### Scenario: Managed config is generated
- **WHEN** either platform-specific Codex config generator runs
- **THEN** its output contains no `[mcp_servers.slack]` table and no `https://mcp.slack.com/mcp` URL

#### Scenario: Slack authentication is required
- **WHEN** the curated Slack plugin requires an account connection on a machine
- **THEN** Codex prompts the user to complete the plugin connection interactively
- **AND** chezmoi SHALL NOT store OAuth credentials, Slack client IDs, or Slack tokens in the repository
