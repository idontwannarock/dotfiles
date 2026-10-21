## Why

The user does not want browser MCP servers to use agent context. Native MCP also cannot be called from a script. `playwright-cli` is a shell command that attaches to the same CDP Chrome. It covers every `cdp.py` action, including an in-page `fetch` with the login cookies.

## What Changes

- Make `playwright-cli`, attached over CDP, the default browser driver.
- Retire `cdp.py`. Remove its source and list its target in `.chezmoiremove`.
- Keep project-scoped Chrome DevTools MCP only for an agent shell that cannot reach Chrome, with user agreement.
- Install `@playwright/cli` with the npm tools on every OS.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `wsl-chrome-browser-session`: Change the default driver from native MCP to `playwright-cli`, and remove the `cdp.py` fallback.

## Impact

Shared skill body, both npm installers, `.chezmoiremove`, `.chezmoiignore.tmpl`, and the Claude and Codex guides. No browser, forwarding, or firewall change.
