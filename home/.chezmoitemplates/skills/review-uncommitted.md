{{ template "skills/code-review-context.md" . }}
## Get Diff

Determine the diff to review:

1. Staged changes exist → `git diff --cached`
2. Unstaged changes exist → `git diff`
3. Clean working tree → `git show HEAD`

Then run `git diff --name-only` (or equivalent for the chosen diff) to get the list of changed files.

## Change-Aware Lens Selection

Classify the changed files, then run only the lenses that apply. Each is a file
under `~/.agent/reference/review-lenses/`.

| Lens | File | Run when |
|------|------|----------|
| correctness | `correctness.md` | **Always** |
| design | `design.md` | Changed files include source code |
| failure-handling | `failure-handling.md` | Changed files include source code |
| tests | `tests.md` | Changed files include test files, **or** source changed and no test did |
| security | `security.md` | The diff touches a trust boundary — input parsing, auth, a network or filesystem path built from input, a dependency or lockfile, a CI or install script |
| conventions | `conventions.md` | Skipped — this flow reviews work in progress; run `{{ .n.reviewFull }}` before it goes out |
| comments | `comments.md` | Skipped — same reason |

File classification hints:
- **Source code**: `*.py`, `*.ts`, `*.js`, `*.go`, `*.rs`, `*.java`, `*.rb`, `*.c`, `*.cpp`, `*.sh`, `*.ps1`, etc.
- **Test files**: files matching `*_test.*`, `*.test.*`, `test_*.*`, `*_spec.*`, `spec_*.*`, or under `test/`/`tests/`/`__tests__/` directories
- **Docs/config**: `*.md`, `*.yml`, `*.yaml`, `*.toml`, `*.json`, `*.ini`, `*.cfg`

The `tests` condition is deliberately asymmetric: source changing **without** a
test changing is the case worth flagging, so it triggers the lens rather than
skipping it.

{{ template "skills/code-review-dispatch.md" . }}
{{ template "skills/code-review-confidence.md" . }}
## Output

---

**Uncommitted Change Review**

**Scope**: [staged / unstaged / HEAD]
**Diff size**: [N files changed, +X/-Y lines]
**Lenses run**: [which ran, and why each skipped one was skipped]

**Summary**: [one sentence on overall quality and most important finding]

🔴 **Critical Issues** (confidence ≥ 80, must fix)
- [issue] — _lens: [lens], confidence: [score]_

🟡 **Suggestions** (confidence ≥ 80, should consider)
- [suggestion] — _lens: [lens], confidence: [score]_

📋 **Minor / Nitpicks** (confidence 50-79, titles only)
- [title]

🟢 **Good Practices**
- [positive observation]

---

## Guardrails

- **Do not modify code** — this is a read-only review
- **Full diff** — every reviewer must receive the full diff, not a summary
- **No findings** — if a lens finds no issues, state that briefly; do not fabricate issues
- **Say what was skipped** — a partial review reported as a whole one is the failure mode this flow is most prone to
