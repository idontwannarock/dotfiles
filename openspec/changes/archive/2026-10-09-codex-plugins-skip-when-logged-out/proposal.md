## Why

On a machine where Codex is installed but not logged in, `codex plugin list` reports no marketplace plugins and `codex plugin add slack@openai-curated` fails with "plugin `slack` was not found in marketplace `openai-curated`". The plugin installer treats that as fatal, so `chezmoi update` aborts and every target that sorts after the installer stays undeployed. A fresh machine hits this on its first apply, because Codex login is an interactive step that comes after the installer runs.

## What Changes

- Both plugin installers check `codex login status` after the `codex` availability check.
- When Codex is not logged in, the installers log a warning that names the fix (`codex login`), skip plugin reconciliation, and exit successfully. The next `chezmoi apply` after login reconciles the plugin.
- When Codex is logged in, behavior is unchanged: a failing `plugin list` or `plugin add` is still fatal.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `codex-plugin-management`: Adds a scenario: when Codex is not logged in, the installer warns and exits successfully without plugin installation.

## Impact

- Affects `home/run_install-04-codex-plugins.sh.tmpl`, `home/run_install-04-codex-plugins.ps1.tmpl`, and `tests/codex-plugin-installer.test.sh`.
- Depends on `codex login status` exiting nonzero when Codex is not logged in. Codex CLI 0.162.0 prints `Not logged in` and exits 1.
