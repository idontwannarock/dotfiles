---
type: Reference
title: Cross-model counterpart profiles
description: "Per-agent-kind launch arguments and exit command for the cross-model review counterpart, so the skill body stays model-neutral."
---

# Cross-model counterpart profiles

Read this when dispatching a counterpart agent in `review-cross-model`.

The skill body is model-neutral by design: it knows the *algorithm* (split, start, prompt, read the findings file, tear down) but not the dialect of any particular agent. Everything kind-specific lives here, as data.

## Why the launch arguments matter

The protocol asks the counterpart to do exactly one write -- its findings file -- while touching nothing else. Under a default sandbox that single write is the one action most likely to raise an approval prompt, and an approval prompt registers as `blocked`, which the skill treats as a failed run. Left unaddressed, the one required write is the one that systematically fails.

Pre-authorizing at launch removes the prompt without widening what the counterpart can do: the repository stays read-only, and only the findings directory becomes writable.

Note the asymmetry: `--add-dir` widens, it does not narrow. The read-only boundary on the repo itself must come from the sandbox/permission flags in the same row, not from the wording of the prompt. Prompt wording is an instruction; the sandbox is an enforcement.

## Profiles

`<FINDINGS_DIR>` is the directory the caller created for this run. `<REPO>` is the repository under review, which is also the counterpart's working directory.

| Kind | Launch arguments | Exit command | Verified |
|------|------------------|--------------|----------|
| `codex` | `--cd <REPO> --sandbox read-only --add-dir <FINDINGS_DIR> --ask-for-approval never` | `/exit` | flags exist (codex-cli 0.146.0); composition unverified -- see below |
| `claude` | `--add-dir <FINDINGS_DIR> --disallowedTools Edit Write NotebookEdit` | `/exit` | flags exist; composition unverified |

Pass launch arguments after `--` on `herdr agent start`:

```
herdr agent start <name> --kind <kind> --pane <id> -- <launch arguments>
```

**Unverified means unverified.** Until a row has been exercised end to end on this machine -- counterpart writes its findings file with no approval prompt, and a write into the repository is refused -- treat that row as a hypothesis. If a launch fails or the counterpart still blocks, degrade and report the reason; do not improvise flags to get past it.

## Kinds not listed here

Skip the pre-authorization and the courtesy exit, and dispatch with defaults. Do **not** guess flags or exit commands by analogy with another kind: a wrong flag either fails the launch outright or, worse, silently widens the sandbox in a direction opposite to the read-only boundary.

A kind that lacks a row is still usable -- it just carries a higher chance of blocking on approval, which the skill already handles by degrading.

## Adding a row

Verify on a real run before writing the row, and say what you verified. A row that was reasoned about but never exercised is worse than an absent row: an absent row degrades loudly, while a wrong row looks authoritative and fails quietly.
