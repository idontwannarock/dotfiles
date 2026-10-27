## 1. Change

- [x] 1.1 Rewrite the skill body without environment-specific commands.
- [x] 1.2 Add `references/wsl.md` with `pw`, launch, stop, and leftover cleanup; add both wrappers.
- [x] 1.3 Update both descriptions and both guides.

## 2. Verification

- [x] 2.1 Run each command block of the rendered reference against a real Windows Chrome.
- [x] 2.2 Render and validate both skills; run the shell suites; validate the specs.

## Verification results

- 2026-10-27: the extracted `pw` block attached to Chrome 155 on `localhost:9222` with no forward. `tab-list`, `goto`, and `--raw eval` with `fetch` (HTTP 200) worked. `click` timed out on a background window without the three `--disable-*` flags and worked with them.
- The extracted stop block stopped Chrome by PID and printed `0`. The extracted launch block started Chrome on `127.0.0.1:9222`.
- No portproxy entry and no `WSL-CDP-*` rule exist after the run.
