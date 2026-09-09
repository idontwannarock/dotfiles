## Context

The current Codex config generators always emit a direct `mcp_servers.slack` URL. Slack requires a pre-registered OAuth client and rejects Codex's fallback dynamic registration, so this entry produces a startup warning and never connects. Codex 0.149.1 again provides a plugin CLI and a built-in `openai-curated` marketplace whose Slack entry references a hosted app connection and requests authentication on install.

The repository has separate Unix/macOS/WSL and Windows config generators because chezmoi cannot dispatch the Unix `modify_config.toml` script on Windows. Both generators currently preserve only `[projects.*]`. A Codex plugin installation writes its registration under `[plugins.*]`, so the next `chezmoi apply` would otherwise delete the installed state.

## Goals / Non-Goals

**Goals:**

- Make `slack@openai-curated` the single Slack integration used by Codex.
- Reconcile the required plugin on every `chezmoi apply` without reinstalling an already enabled plugin.
- Preserve local Codex plugin registration across managed config regeneration.
- Keep the Unix and Windows implementations behaviorally aligned.
- Keep Slack OAuth credentials and account-specific connection state outside the repository.

**Non-Goals:**

- Create or manage a Slack app, OAuth client ID, token, or workspace approval.
- Reuse the client ID bundled for Claude Code.
- Manage arbitrary third-party Codex marketplaces.
- Repair unrelated Codex-generated config sections, including the observed `[hooks.state]` drift.
- Change the Claude Code Slack plugin setup.

## Decisions

### Install the curated Slack plugin instead of configuring Slack MCP directly

Use `codex plugin add slack@openai-curated --json` and remove the managed `[mcp_servers.slack]` table. The curated entry delegates authentication to its app connection and avoids the unsupported DCR path.

Alternatives considered:

- **Configure a private Slack client ID:** rejected because it adds Slack app ownership, redirect registration, and per-workspace administration that the curated plugin already handles.
- **Reuse Claude Code's bundled client ID:** rejected because that app and its callback registration belong to the Claude integration and are not a portable Codex contract.
- **Keep both integrations:** rejected because the direct entry continues to warn and exposes a duplicate Slack tool surface if it ever authenticates.

### Reconcile plugins with a dedicated `run_install-04-codex-plugins` pair

Add one bash template and one PowerShell template with the same basename. They run after `run_install-02-npm-tools`, which installs Codex, and after chezmoi writes `config.toml`. Each script obtains one `codex plugin list --json` snapshot, skips Slack only when it is both installed and enabled, and otherwise runs `codex plugin add`.

Use a regular `run_` script rather than `run_once_` or `run_onchange_`. If Codex is temporarily absent, a regular script retries on the next apply; it also repairs a plugin that was later removed or disabled. The installed-and-enabled check keeps repeat cost low.

The scripts use the shared logging fragments. Missing Codex is a logged skip because the earlier tool installer may be unavailable temporarily. A malformed list response or failed plugin add is a real failure because the required state was not reached.

Alternatives considered:

- **Declare `[plugins.*]` directly in the config generator:** rejected because the Codex CLI owns plugin download, cache, marketplace resolution, and installation behavior.
- **Fold plugin installation into `run_install-02-npm-tools`:** rejected because npm tool installation and Codex marketplace reconciliation have different commands and failure boundaries.
- **Use `run_onchange_`:** rejected because an apply that cannot find Codex could record the script hash and never retry.

### Preserve every `[plugins.*]` table as per-machine state

Extend both config generators' existing keep filter from `[projects.*]` to `[projects.*]` and `[plugins.*]`. Preserve all plugin tables rather than hard-coding Slack so user-installed plugins survive an apply. Continue to trim only trailing separator whitespace so each generator remains a fixed point.

Do not preserve custom marketplace tables in this change. `openai-curated` is built in, and marketplace management is outside the requested scope.

### Separate plugin installation from OAuth connection

chezmoi owns only the installed-and-enabled plugin state. The plugin/app flow owns OAuth and stores its credentials outside the repository. Documentation will tell the user to complete the connection when Codex prompts and then start a new session. Tests will not inspect or copy credentials.

### Test through the CLI seam

Use a temporary home and a stub `codex` executable for the installer regression loop. Cover first install, repeat skip, disabled repair, missing CLI, and CLI failure. Separately feed config fixtures containing both project and plugin tables through the Unix generator twice to verify preservation and fixed-point output. Use static/render checks for the PowerShell twin where PowerShell execution is unavailable.

## Risks / Trade-offs

- **The curated Slack plugin may be unavailable for an account or workspace.** → Let `codex plugin add` fail clearly; do not silently restore the known-broken direct MCP entry.
- **Plugin installation can require interactive authentication.** → Treat local plugin registration and Slack account connection as separate states, and document the one-time interactive step.
- **Codex can change the JSON shape of `plugin list`.** → Fail on an unparseable response and cover the currently observed contract with a stub test.
- **Preserving all plugin tables also preserves a locally disabled plugin.** → The required Slack reconciler explicitly repairs Slack to enabled; other plugins remain user-owned.
- **Windows behavior cannot be fully exercised on this Linux host.** → Keep both scripts structurally parallel, render the Windows guard, and add static parity assertions; report Windows runtime verification as pending unless a Windows host is used.

## Migration Plan

1. On the current machine, install `slack@openai-curated`, complete or confirm its Slack connection, and verify a new Codex session exposes Slack tools.
2. Update both config generators to preserve `[plugins.*]` and stop emitting the direct Slack MCP entry.
3. Add the cross-platform plugin reconciler scripts and regression tests.
4. Apply the scoped chezmoi changes. Run a second apply to verify no reinstall and no config churn.
5. Verify a new Codex session no longer reports the direct Slack MCP startup failure.

Rollback removes `slack@openai-curated` with `codex plugin remove` and reverts the repository change. Reintroducing the direct Slack MCP entry restores the previous configuration but also restores its known OAuth failure, so a no-Slack state is the safer operational fallback.

## Open Questions

None. The local Codex CLI and marketplace snapshot establish the required command, plugin identifier, config table, and install policy.
