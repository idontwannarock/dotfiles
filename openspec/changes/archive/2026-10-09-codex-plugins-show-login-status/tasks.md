## 1. Show the login status output in the skip warning

- [x] 1.1 In `tests/codex-plugin-installer.test.sh`, make the `logged-out` case assert that the output contains the stub's `Not logged in` text. Verify it fails before 1.2.
- [x] 1.2 Capture `codex login status` output (stdout and stderr, joined to one line) in both installers and put it in the warning. Verify the test passes and the rendered ps1 prints `Not logged in` on this logged-out machine.
