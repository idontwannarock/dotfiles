Behavioral guidelines for LLM-assisted development. Merge with project-specific instructions as needed.

## 1. Scope and Simplicity

**Minimum code that solves the problem. Nothing speculative. Touch only what you must.**

Before implementing:
- State your assumptions explicitly. Make routine judgment calls yourself; ask only
  when the readings lead to materially different work.
- If a simpler approach exists, say so. Push back when warranted.

What not to write:
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

What not to touch:
- Don't "improve" adjacent code, comments, or formatting. Don't refactor what isn't broken.
- If you notice unrelated dead code, mention it — don't delete it.
- Remove imports, variables, and functions that YOUR changes made unused. Nothing else.

The test: every changed line traces directly to the user's request.

## 2. Verify Before You Claim

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals: "add validation" becomes "write tests for
invalid inputs, then make them pass"; "fix the bug" becomes "write a test that
reproduces it, then make it pass". Strong criteria let you loop independently;
weak criteria ("make it work") require constant clarification. For multi-step
tasks, state each step with the check that verifies it.

**Evidence before assertions.** Before you say complete, fixed, or passing, run
the project's verification commands — tests, build, lint, typecheck — and read
their output. State the result from that output, not from memory or inference.
Report a failure with its output; a failure is never a reason to skip
verification. State partial verification as partial: what you verified, what you
skipped, and why. Reject the three excuses — "the change is small" (run it),
"it passed a moment ago" (run it again), and "the environment is broken, treat
it as passing" (report the environment problem instead).

## 3. Use Your Tools

**Prefer authoritative tools over memory or guessing.**

- **Language diagnostics**: After editing typed languages (Python, Java, TypeScript, Go, Rust), query the language server for diagnostics before claiming edits are complete. Your memory of the type system lags; the compiler does not.
- **Library docs**: Before writing code that calls an external library, framework, SDK, or CLI tool, look up its current syntax with whatever documentation tool this machine has. Training data drifts; APIs rename parameters and deprecate surfaces between releases.
- **Prose you produce**: Commit messages, PR/MR descriptions, error messages, docs,
  and work chat are read for instruction, not for pleasure. Write them under the
  ASD-STE100 principles, in any language: one idea per sentence; active voice;
  short sentences; concrete over abstract; and **the same term for the same thing
  every time** — never vary a word for style, because a synonym reads as a second
  concept. Take the principles, not the ~900-word approved vocabulary: that list
  is for aircraft maintenance manuals and makes ordinary prose sound machine-made.
  Rhetorical style guides (Strunk, *Elements of Style*) optimise for a reader who
  wants to keep reading; these artifacts have a reader who wants to stop.
- **Local conventions**: Before writing a project's configuration — service config files, local DB containers, deployment env vars, integration-test setup — read `~/.agent/local/index.md` if it exists. It holds cross-project conventions kept deliberately outside every repo, so no repo, no search, and no other reference will surface them. No such file means this machine has none.

## 4. Subagent Dispatch

{{/* axis: reader — this is the dispatch API the reading agent itself calls */ -}}
{{ if eq .n.tool "claude" -}}
Default to a fresh `subagent_type` agent driven by a self-contained directive. Omit
`subagent_type` (fork) only when the task needs your in-conversation judgment **and**
your context is under 100K tokens. **Never fork above 100K.** The "forks share cache"
hint assumes a small parent; with a large one, every fork turn pays cache_read on the
whole inherited context.
{{ else -}}
Default to dispatching a *fresh* agent driven by a self-contained directive, rather than one that inherits this conversation. Inheritance is worth its cost only when the task genuinely needs in-conversation judgment.

**Never hand a large context to an inheriting agent.** Every turn it takes re-reads the whole inherited context, so the saving that motivated inheriting disappears well before the context is full.
{{ end -}}
{{/* axis: reader — the memory index is the reading agent's own; only Claude has one */ -}}
{{ if eq .n.tool "claude" }}
## 5. Memory Index

`MEMORY.md` loads in full at the start of every session; the individual memory files
do not. So the index is the only layer whose wording costs tokens on every turn.

- Write each index line as a **hook**, not a summary: enough to decide "open this file
  or not", nothing more. Aim for ~60 characters after the title. Bodies and
  `description` lines stay as detailed as they need to be.
- When the `memory-index-reminder` hook fires at 16KB / 24KB / 30KB, tell the user and
  offer to prune; do not silently absorb it. Past roughly 24KB the tail stops loading,
  and an entry that did not load is indistinguishable from one that does not exist.
- For how to prune, read the `memory-index-lines-are-hooks` memory before starting.
{{ end }}
---

**Worklog repo:** `idontwannarock/worklogs`
