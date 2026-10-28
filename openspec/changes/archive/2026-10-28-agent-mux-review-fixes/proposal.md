## Why

A surgical review of `bdf2456` found five defects in `agent-mux`. Three are critical. Under herdr, `exit` can press Enter on a Codex update dialog. A failed `herdr pane close` reports `closed` and leaves a shell pane open. A short Ghostex query failure reads as "agent gone".

## What Changes

- `exit` always sends Escape first, on both backends.
- herdr `close` finds the pane by its terminal id, checks the close result, and confirms that the terminal is gone.
- Liveness has three results: alive, gone, query failed. A failed query is never "gone".
- Ghostex `start` matches a linked worktree to its project by git common directory and passes the worktree as cwd.
- `prompt` exits 0 for `unknown`, as the skill's table already says.
- Every backend function takes `name`; `load()` refuses an unknown backend; the per-verb dispatch `case` is gone.
- Found during the live re-test: Ghostex `providerSessionState` reads `exists` for about 30 seconds after the terminal ends. Ghostex liveness now also asks the terminal with `read-text`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `cross-model-review`: the exit, close, liveness, worktree, and `unknown` rules above.

## Impact

`home/dot_local/bin/executable_agent-mux`, `tests/agent-mux.test.sh`, one sentence in the `review-cross-model` body, `docs/user-scripts.md`. State files written by the old `start` have no terminal id, so the old `close` refuses them; none exist outside the test runs, which were cleaned up.
