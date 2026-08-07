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

## The working directory is the writable root -- and it is the repo

Every kind tested grants write access to the agent's working directory, and none can be writable in one subdirectory while read-only in the rest. So there is no arrangement in which the counterpart both works inside the repo and cannot write to it.

Given that, the working directory is the **repo**, and the counterpart writes its findings to the gitignored `<REPO>/.cross-model-review/<run id>/`.

The deciding factor is not the sandbox but the session record: an agent's transcript is filed under its working directory. Parking the counterpart in a scratch path under `~` archives the review conversation against a directory that gets deleted -- present in the history, unreachable from the project. Keeping it in the repo keeps the conversation attached to what it reviewed.

The repo's contents are then protected by a before/after comparison of the working tree, not by the sandbox. That trade is proportionate only because the target is version-controlled.

Split the pane with `--cwd <REPO>`.

## Profiles

`<REPO>` is the repository under review, and the counterpart's working directory.

| Kind | Readiness probe | Launch arguments | Exit command | Confines writes to the repo? |
|------|------------------|--------------|------------------------------|
| `codex` | `codex login status` | `--cd <REPO> --sandbox workspace-write --ask-for-approval never` | `/exit` | **Yes** -- verified 2026-08-06, codex-cli 0.146.1 |
| `claude` | `claude --version` | `--permission-mode acceptEdits --allowedTools "Bash(git diff:*)" "Bash(git log:*)" "Bash(git show:*)" "Bash(git status:*)" "Bash(git ls-files:*)"` | `/exit` | **Yes** -- verified 2026-08-07, but see the note |

Both rows launch with the pane's cwd set to `<REPO>`, and **neither passes `--add-dir`**. That absence is the confinement for claude: its file tools stay within the working directory tree, so a write outside the repo raises a permission prompt instead of landing. An earlier draft passed `--add-dir <REPO>` with the workspace elsewhere and concluded claude could not be confined -- that conclusion was an artifact of the test configuration, not a property of the tool.

The claude confinement differs from codex's in how it fails: codex refuses the write outright and carries on, while claude stops at a prompt and registers as `blocked`. Both prevent the write; only codex lets the run continue afterwards.

The git allowance in the claude row is deliberately narrow. An earlier draft used `Bash(git *)`, which pre-authorizes `git reset --hard` and `git clean` -- destructive commands handed to an agent whose entire job is to read.

### The probe column is not a verified fact

The two columns record different kinds of thing, and conflating them produces a table that rots:

| Column | Records | Lifetime |
|--------|---------|----------|
| `Confines writes` | what the flags mean | stable; re-verify only when the CLI changes |
| `Readiness probe` | **the command to run**, never its result | the answer is session state and changes whenever the user logs in or out |

Run the probe every time. Never write its outcome into this table, into a memory, or into any document. "codex was not authenticated" is true for exactly as long as it takes the user to log in again, and a cached copy of it would suppress the counterpart forever after.

Pass launch arguments after `--` on `herdr agent start`:

```
herdr agent start <name> --kind <kind> --pane <id> -- <launch arguments>
```

### What was probed, 2026-08-06

With the workspace set to a directory *other* than the repo, codex behaved exactly as its flags promise: reads outside the workspace succeeded without approval, writes inside succeeded, and a write into the repo was refused with `read-only file system`. That is the evidence behind "the workspace is the writable root".

Two combinations that do **not** work, so nobody re-derives them:

- **codex `--sandbox read-only` with `--add-dir`** is rejected outright: *"Ignoring --add-dir because the effective permissions do not allow additional writable roots."* Read-only and an extra writable root are mutually exclusive.
- **claude `--disallowedTools "Write(<REPO>/**)"`** does not block the write. The tool-pattern denial did not override directory access, and the counterpart wrote into the repo and reported doing so.

So no kind gives "writable here, read-only there". Hence detection rather than prevention.

### Notes per kind

**codex** -- `workspace-write` with the repo as workspace confines writes to the repo. Writes elsewhere on disk still require approval, which with `--ask-for-approval never` become plain failures rather than a blocked prompt.

**claude** -- confined by its working directory, provided no extra directory is added. Note that `--permission-mode acceptEdits` covers edits only, **not** Bash: without a `Bash(...)` allowance the counterpart blocks on its first `git` command.

The Step 6 tree comparison still runs for eligible kinds. Confinement and comparison cover different things -- confinement bounds where damage can land, comparison tells you whether any landed inside those bounds. Neither substitutes for the other, and neither can undo an edit to a file the user had not committed.

**Unverified means unverified.** A row that was reasoned about but never exercised is worse than an absent row: an absent row degrades loudly, a wrong row looks authoritative and fails quietly. If a launch fails or the counterpart still blocks, degrade and report the reason; do not improvise flags to get past it.

## Kinds not listed here

Skip the pre-authorization and the courtesy exit, and dispatch with defaults. Do **not** guess flags or exit commands by analogy with another kind: a wrong flag either fails the launch outright or, worse, silently widens the sandbox in a direction opposite to the read-only boundary.

A kind that lacks a row is still usable -- it just carries a higher chance of blocking on approval, which the skill already handles by degrading.

## Adding a row

Verify on a real run before writing the row, and say what you verified. A row that was reasoned about but never exercised is worse than an absent row: an absent row degrades loudly, while a wrong row looks authoritative and fails quietly.
