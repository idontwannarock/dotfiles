## Why

Surgical review found two target-selection gaps in the revised skill. The default MCP requires `select_page` for a non-selected tab, and the existing `cdp.py` always connects to port 9222.

## What Changes

- Allow native page selection before a target snapshot and inspect the loaded schema before using `pageId`.
- Reject `cdp.py` fallback when its fixed endpoint does not match the intended session.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `wsl-chrome-browser-session`: Require explicit tab and endpoint matching before reading or operating the browser.

## Impact

Updates shared skill instructions and the existing Codex guide only. No helper code, browser, network rule, or cleanup-project setting changes. The user approved these two review fixes and spec synchronization.
