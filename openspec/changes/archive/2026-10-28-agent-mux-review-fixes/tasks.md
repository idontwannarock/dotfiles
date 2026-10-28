## 1. Fixes

- [x] 1.1 Escape before every exit command, in the shared `exit` verb
- [x] 1.2 herdr close by terminal id, with checked result and confirmation
- [x] 1.3 Three-way liveness; a failed query is not gone
- [x] 1.4 Ghostex project match by git common directory; worktree as cwd
- [x] 1.5 `prompt` exits 0 for `unknown`
- [x] 1.6 Uniform backend functions; `load()` validates the backend
- [x] 1.7 Ghostex liveness asks the terminal (read-text), because the session list lags about 30 seconds

## 2. Verification

- [x] 2.1 Each of 1.1-1.5 has a test that goes red when the fix is reverted
- [x] 2.2 Shell tests under sh and bash; `openspec validate --all --strict`
- [x] 2.3 Live round trip on Ghostex (incl. a linked worktree) and on an isolated herdr session
