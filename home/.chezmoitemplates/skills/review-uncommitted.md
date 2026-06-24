---
name: review-uncommitted
description: Review uncommitted changes with change-aware agent dispatch — use during development to check work before committing
---

## Context

First, gather context by running these commands:

- `git status --short` — working tree state
- `git branch --show-current` — current branch

## Get Diff

Determine the diff to review:

1. Staged changes exist → `git diff --cached`
2. Unstaged changes exist → `git diff`
3. Clean working tree → `git show HEAD`

Then run `git diff --name-only` (or equivalent for the chosen diff) to get the list of changed files.

## Change-Aware Dispatch

Classify changed files and dispatch only relevant review tasks **in parallel**. Each task receives the full diff.

| Review Task | Agent Type | Dispatch Condition |
|-------------|-----------|-------------------|
| Code quality, style, bugs, naming | `code-reviewer` | **Always** |
| Silent failures, error handling, swallowed exceptions | `silent-failure-hunter` | Changed files include source code (not just docs/markdown/config) |
| Test coverage, missing edge cases | `pr-test-analyzer` | Changed files include test files |
| Architecture simplicity, unnecessary complexity | `linus-torvalds` | Changed files include source code (not just docs/markdown) |

File classification hints:
- **Source code**: `*.py`, `*.ts`, `*.js`, `*.go`, `*.rs`, `*.java`, `*.rb`, `*.c`, `*.cpp`, etc.
- **Test files**: files matching `*_test.*`, `*.test.*`, `test_*.*`, `*_spec.*`, `spec_*.*`, or under `test/`/`tests/`/`__tests__/` directories
- **Docs/config**: `*.md`, `*.yml`, `*.yaml`, `*.toml`, `*.json`, `*.ini`, `*.cfg`

{{ template "skills/code-review-confidence.md" . }}
## Output

---

**Uncommitted Change Review**

**Scope**: [staged / unstaged / HEAD]
**Diff size**: [N files changed, +X/-Y lines]
**Agents dispatched**: [list which agents ran and why others were skipped]

**Summary**: [one sentence on overall quality and most important finding]

🔴 **Critical Issues** (confidence ≥ 80, must fix)
- [issue] — _source: [agent], confidence: [score]_

🟡 **Suggestions** (confidence ≥ 80, should consider)
- [suggestion] — _source: [agent], confidence: [score]_

📋 **Minor / Nitpicks** (confidence 50-79, titles only)
- [title]

🟢 **Good Practices**
- [positive observation]

---

## Guardrails

- **Do not modify code** — this is a read-only review
- **Full diff** — every dispatched task must receive the full diff, not a summary
- **No findings** — if a task finds no issues, state that briefly; do not fabricate issues
