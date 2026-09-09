## Why

The synced Codex configuration enables Slack as a direct remote MCP server without the fixed OAuth client ID that Slack requires. Codex therefore attempts unsupported dynamic client registration at every startup, while the current `openai-curated` marketplace already provides a Slack plugin whose app connection owns authentication.

## What Changes

- Install and keep `slack@openai-curated` enabled through chezmoi on every supported platform.
- Remove the directly managed `[mcp_servers.slack]` entry so Codex no longer starts an unauthenticated duplicate Slack connection.
- Preserve Codex's per-machine `[plugins.*]` registry when the managed `config.toml` is regenerated.
- Keep Slack OAuth credentials outside the repository and let the plugin connection handle interactive authentication.
- Document the plugin-based setup and add regression coverage for installation, idempotency, config preservation, and Unix/Windows parity.

## Capabilities

### New Capabilities

- `codex-plugin-management`: Defines how chezmoi installs and retains required Codex marketplace plugins, including the Slack app connection.

### Modified Capabilities

- `chezmoi-script-conventions`: Extends the Codex config generator contract so both platform implementations preserve per-machine plugin registration while remaining fixed points.

## Impact

- Affects the Codex plugin installer scripts, both platform-specific `config.toml` generators, their tests, and `docs/codex-cli.md`.
- Depends on the Codex CLI `plugin` command and its built-in `openai-curated` marketplace.
- Removes the obsolete direct Slack MCP startup path; existing OAuth tokens remain local and unmanaged.
