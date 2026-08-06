---
name: review-comprehensive
description: Comprehensive code review of commit ranges, branches, or entire codebase — all agents, confidence scoring
---

## Context

First, gather context by running these commands:

- `git status --short` — working tree state
- `git branch --show-current` — current branch

{{ template "skills/code-review-scope.md" . }}
## Task

After obtaining the diff, dispatch **all review tasks in parallel**. Each task receives the full diff.

| Review Task | Agent Type | Focus |
|-------------|-----------|-------|
| Code quality + security | `code-reviewer` | Style, best practices, bugs, naming. **Also**: injection attacks (SQL/command/XSS), auth/authz issues, sensitive data exposure, OWASP Top 10 |
| Silent failures | `silent-failure-hunter` | Error handling, swallowed exceptions, inappropriate fallback, data loss paths |
| Test coverage | `pr-test-analyzer` | Missing tests, edge cases, test quality and maintainability |
| Architecture | `linus-torvalds` | Simplicity, unnecessary complexity, good taste, special cases that should disappear, backward compatibility |
| Type design | `type-design-analyzer` | Encapsulation, invariant expression, type safety, enforcement quality |
| Comment accuracy | `comment-analyzer` | Comment accuracy vs actual code behavior, stale comments, missing critical comments |

{{ template "skills/code-review-confidence.md" . }}
## Cross-model rebuttal

The six lenses above and the confidence pass all run on one model family. They differ by prompt, not by priors, and each of them read evidence you selected. That structure is good at rejecting misjudgements and blind to shared omissions.

So the filtered findings are not the verdict yet -- they are one side of an exchange. Run `review-cross-model` with them.

Its inputs and outputs:

- **In**: the findings that survived the confidence filter. The filter is the noise gate; unfiltered findings sent to a counterpart dilute the exchange and cost a round trip.
- **Out**: the counterpart's own findings (scored through the same filter, so the two sets are comparable), plus one round of rebuttal each way.

Confidence no longer decides severity here -- it decides what is worth arguing about. Severity comes from the exchange:

| Outcome | Grade |
|---------|-------|
| Both sides raised it, or one raised it and the rebuttal failed | Critical |
| Successfully refuted | Downgrade or drop, stating the refutation |
| Raised by one side only, uncontested | **Split** -- present both positions, do not resolve it |

If the cross-model leg does not run, say so in the report and grade on confidence alone. A single-model review is a legitimate result; a single-model review presented as a cross-verified one is not.

## Output

---

**Comprehensive Code Review**

**Scope**: [reviewed what — PR #N / branch diff / commit range / staged / HEAD]
**Diff size**: [N files changed, +X/-Y lines]
**Cross-model rebuttal**: [counterpart kind, or `not run — <reason>`]

**Summary**: [one sentence on overall quality and most important finding]

🔴 **Critical Issues** (must fix)
- [issue] — _source: [agent], upheld by: [both sides / rebuttal failed]_

🟡 **Suggestions** (should consider)
- [suggestion] — _source: [agent]_

⚖️ **Split** (the two models disagree — your call)
- [finding] — _raised by: [side]. Their position: [...]. The other side: [...]_

🚫 **Refuted** (raised, then withdrawn)
- [finding] — _refuted because: [...]_

📋 **Minor / Nitpicks** (confidence 50-79, titles only)
- [title]

🟢 **Good Practices**
- [positive observation]

**Details by Perspective**

_Code Quality & Security_ (code-reviewer)
...

_Error Handling_ (silent-failure-hunter)
...

_Test Coverage_ (pr-test-analyzer)
...

_Architecture & Simplicity_ (linus-torvalds)
...

_Type Design_ (type-design-analyzer)
...

_Comment Accuracy_ (comment-analyzer)
...

---

## Guardrails

- **Do not modify code** — this is a read-only review
- **Full diff** — every task must receive the full diff, not a summary
- **Large diffs** — if over 500 lines changed, note at the top that the user may want to split the review
- **No findings** — if a task finds no issues, state that briefly; do not fabricate issues
- **Spec alignment** — if the project has an active OpenSpec change, mention that `review-spec` (in the OpenSpec workflow) can check requirement alignment
