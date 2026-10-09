## 1. Skip plugin reconciliation when Codex is not logged in

- [x] 1.1 Add a `logged-out` case to `tests/codex-plugin-installer.test.sh`: the stub `codex login status` exits 1; assert exit 0, a `codex login` warning, an `ok` closing banner, and no `plugin list` or `plugin add` call. Make the stub's `login status` exit 0 for all other cases. Verify the new case fails before 1.2.
- [x] 1.2 Add the login check to `home/run_install-04-codex-plugins.sh.tmpl` after the `codex` availability check, and verify `sh tests/codex-plugin-installer.test.sh` passes.
- [x] 1.3 Add the same check to `home/run_install-04-codex-plugins.ps1.tmpl` (`return`, not `exit`), add a source assertion for it to the test, and verify the test passes and `chezmoi execute-template` renders the ps1 on Windows.
- [x] 1.4 Document the login prerequisite in `docs/codex-cli.md` section 6, and verify the text names `codex login`.
