## Why

The skill treats an earlier headless-browser failure as a permanent MCP limitation. A live cleanup session has now demonstrated that native Chrome DevTools MCP can control an authenticated Windows Chrome even when the agent shell cannot reach it.

## What Changes

- Separate Chrome connection setup from the choice of browser driver.
- Prefer authorized native MCP tools; retain `cdp.py` as a scoped fallback.
- Diagnose Windows, WSL, agent-shell, and MCP connectivity separately.
- Scope MCP configuration to the task project and start with read-only tools.
- Inspect listeners before choosing port forwarding. Limit firewall exposure.
- Reuse active sessions and separate browser shutdown, forwarding removal, and profile deletion.
- Keep Codex and Claude skill wrappers aligned.

## Capabilities

### New Capabilities

- `wsl-chrome-browser-session`: Safe setup, driver selection, verification, and teardown for authenticated Windows Chrome sessions used from WSL.

### Modified Capabilities

None.

## Impact

Changes the shared skill body, its two wrapper descriptions, and the relevant user documentation. No browser code, package installation, global MCP registration, or live browser/network settings change. Remote fetch is unavailable in this execution environment; the branch starts from the matching local `main` and cached `origin/main`.
