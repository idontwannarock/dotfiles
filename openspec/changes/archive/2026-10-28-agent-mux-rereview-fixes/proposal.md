## Why

A re-review of `25c0693` found three issues in `agent-mux`. One is a regression: on Ghostex, a settled agent that the script cannot classify (`unknown`) made `prompt` wait until the timeout. The skill then reported `counterpart timed out` instead of reading the findings file.

## What Changes

- The backend state functions print `queryfail` when the multiplexer does not answer. The Ghostex prompt wait skips only `queryfail`; `unknown` settles after the grace period. The `state` verb still prints `unknown` for both.
- The herdr state file stores only `backend=herdr` and the terminal id. The pane id stays local to `start`.
- `ghostex_project` returns its error instead of calling `die` inside a command substitution, so a failed `ghostex state` no longer adds a second, false "not in a Ghostex project" line.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `cross-model-review`: the herdr state file content, the `unknown` settle rule, and the `ghostex state` error message.

## Impact

`home/dot_local/bin/executable_agent-mux` and `tests/agent-mux.test.sh` only.
