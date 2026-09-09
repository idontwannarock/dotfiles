## 1. Prove the replacement on the current machine

- [x] 1.1 Install `slack@openai-curated` with the real Codex CLI, complete or confirm its Slack connection, and verify a new session exposes Slack tools without relying on the direct `mcp_servers.slack` entry.

## 2. Preserve plugin state and remove the broken direct connection

- [x] 2.1 (blocked by 1.1) Add a failing config-generator regression test for `[projects.*]` plus `[plugins.*]` preservation, fixed-point output, Unix/Windows keep-filter parity, and absence of the direct Slack MCP; then update both config generators until it passes.

## 3. Reconcile the curated plugin across platforms

- [x] 3.1 (blocked by 2.1) Add a failing stub-based installer test for missing, enabled, disabled, unavailable-CLI, malformed-list, and failed-add cases; then add the bash and PowerShell `run_install-04-codex-plugins` templates with shared logging until the test and template render checks pass.

## 4. Document and verify the deployed path

- [x] 4.1 (blocked by 3.1) Update `docs/codex-cli.md` to describe plugin installation, per-machine authentication, and removal of the direct MCP path; verify script ordering and Unix/Windows plugin identifier parity.
- [x] 4.2 (blocked by 4.1) Run all repository tests, OpenSpec validation, template syntax/render checks, config fixed-point checks, and scoped `chezmoi diff`/apply twice; then start a fresh Codex session and confirm the Slack MCP startup warning is gone without exposing credentials.
