## Why

The plugin installer skips plugin reconciliation whenever `codex login status` exits nonzero, and its warning tells the user to run `codex login`. A nonzero exit can also mean a broken auth or config file, or a stale `codex` shim first on PATH. The installer discards the command output, so the real cause is hidden and the warning points to the wrong fix.

## What Changes

- Both plugin installers include the output of `codex login status` in the skip warning.
- The skip itself is unchanged: any nonzero exit still skips plugin reconciliation and exits successfully.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `codex-plugin-management`: The "Codex is not logged in" scenario requires the warning to include the `codex login status` output.

## Impact

- Affects `home/run_install-04-codex-plugins.sh.tmpl`, `home/run_install-04-codex-plugins.ps1.tmpl`, and `tests/codex-plugin-installer.test.sh`.
