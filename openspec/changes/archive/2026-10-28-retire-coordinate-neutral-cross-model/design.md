## Context

`review-cross-model` drove herdr directly: `pane split`, `agent start`, `agent prompt --wait`, `agent get`, `agent read`, `pane close`, `agent list`. The user now also runs Ghostex (v10.31.0, WSL backend). Ghostex has a CLI but no split pane, no `--wait`, and no way to pass launch arguments to `create-agent`.

## Goals / Non-Goals

**Goals:**
- One skill body for both multiplexers, with every existing protocol guarantee kept.
- A detect step that cannot be fooled by an environment variable.

**Non-Goals:**
- More backends (tmux, zellij). Add one only after a live round trip.
- Changing the `ListAgents` permission.

## Decisions

**A script, not a reference doc.** The user chose a script. It also lets the script hold guarantees itself: `prompt` checks liveness before it types, and `close` acts only on what `start` recorded. A reference doc would leave both to the reader.

**State file per name.** herdr needs a pane id and Ghostex needs a session ref. `start` writes the one it got to `~/.local/state/agent-mux/<name>.env`. The caller uses only `<name>`. Alternative: print an opaque handle. Rejected: herdr pane ids contain `:`, and the caller would have to carry two values.

**Ghostex: `create-session --input "exec <cmd> <args>"`, not `create-agent`.** `create-agent` takes no arbitrary arguments, so the codex sandbox flags could not be passed. Ghostex still detects the agent in a terminal session (verified: `agentId` becomes `codex`). `exec` makes the terminal end with the agent. That gives a liveness signal (`providerSessionState`), and it removes the shell that would otherwise receive typed text. Ghostex's own `activity` cannot be used for liveness: it stayed `idle` after codex quit.

**Ghostex settle rule.** Poll every 2 seconds. Settle on the first non-`working` state after `working` was seen, or after a 10-second grace. A short turn can finish between polls; the findings file decides what happened.

**`attention` is ambiguous.** It means both "waiting for permission" and "finished, not yet viewed". The agent's own program status separates them (`blocked` / `done`). Without it, report `unknown` and let the findings file decide.

**Escape before every Ghostex exit command.** A Codex update offer at startup reads as `idle`, and Enter on it selects "Update now". This happened once during verification.

**Repo must already be a Ghostex project.** `add-project` would change the user's sidebar, so `start` fails instead.

**Bash, not gated by OS.** Like `media-fetch` and `spotify-api`, the script is not in `.chezmoiignore.tmpl`. `detect` refuses on any machine without herdr or Ghostex, so deploying it is harmless. Windows and macOS are not verified.

## Risks / Trade-offs

- [The herdr backend `alive` reads `agent get` failure as gone] → Verified live: herdr drops an exited agent (`agent_not_found`).
- [Ghostex output fields can change between versions] → Tests pin the fields used; a live round trip is in `docs/user-scripts.md`.
- [`jq -e` exits 0 on empty input] → A `jtest` helper treats empty input as false. Found during verification: herdr writes its error JSON to stderr.
