## Why

The user finds the `coordinate` skill of little use. It is 1,660 lines of skill body, three tests, and two spec sections that every reader pays for. Separately, `review-cross-model` works only inside herdr. The user now also runs Ghostex, and there the skill degrades every time. Its Step 0 also trusts `HERDR_ENV=1`, which is set under the Codex sandbox while every herdr command fails.

## What Changes

- **BREAKING** Retire `coordinate`: delete the shared body, both wrappers, and the two tests that guard only it (`coordinate-section-xref`, `carrier-contract-sync`). Add both deployed paths to `home/.chezmoiremove`.
- Delete the "coordinated mode" section of `dev-workflow` and the `coordinate` key in both name-maps.
- Add `~/.local/bin/agent-mux`: a bash adapter with a herdr backend and a Ghostex backend. Verbs: `detect`, `start`, `alive`, `state`, `prompt`, `classify-read`, `exit`, `close`.
- Rewrite `review-cross-model` so it names no multiplexer command. All terminal control goes through `agent-mux`.
- Fix the detect bug: each backend needs its environment variable **and** a successful read-only command.
- Rename the herdr-specific degrade reasons to `agent-mux not installed` and `no agent multiplexer available — <detail>`. Add `counterpart prompt failed — <detail>` and the report line `teardown not confirmed — <detail>`.
- Reword docs and comments that name `coordinate` as a live skill. Leave history (archived changes, examples in `context/principles.md`) as it is.

## Capabilities

### New Capabilities

None. `agent-mux` belongs to `cross-model-review`.

### Modified Capabilities

- `cross-model-review`: multiplexer-neutral flow through `agent-mux`, real-command detection, the Ghostex backend, neutral degrade reasons.
- `discipline-skills`: six skills instead of seven; every `coordinate` requirement is removed.
- `workflow-instructions`: the two coordinated-mode requirements are removed.
- `model-invocability`: the `review-cross-model` example no longer says "herdr pane".

## Impact

- Deployed: `~/.claude/skills/coordinate` and `~/.codex/skills/coordinate` are removed on the next apply. `~/.local/bin/agent-mux` is added.
- `docs/claude-code.md` and the `modify_settings.json.sh.tmpl` comment: `ListAgents` was left out of `permissions.deny` only for `coordinate`. The permission does not change in this change; the docs now say that the reason is gone.
- Not touched: the coordinate v2 backlog in another repo's handoff directory.
