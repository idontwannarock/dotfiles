{{ template "skills/code-review-context.md" . }}
{{ template "skills/code-review-scope.md" . }}
## Lenses

Run all seven. Each is a file under `~/.agent/reference/review-lenses/`.

| Lens | File | The question |
|------|------|--------------|
| correctness | `correctness.md` | Does this code do the wrong thing? |
| failure-handling | `failure-handling.md` | When something goes wrong, does anyone find out? |
| tests | `tests.md` | If this change broke, would a test go red? |
| design | `design.md` | Is the structure right — and could it be simpler? |
| comments | `comments.md` | Does the prose still describe the code? |
| conventions | `conventions.md` | Does this follow the rules this repo wrote down? |
| security | `security.md` | Can someone make this do something it should not? |

The lenses were split so a finding belongs to exactly one of them. If the same
issue arrives from two lenses, that is a defect in the lens boundary, not a
corroboration — report it once and say which two lenses produced it.

{{ template "skills/code-review-dispatch.md" . }}
{{ template "skills/code-review-confidence.md" . }}
## Cross-model rebuttal

The seven lenses above and the confidence pass all run on one model family. They differ by prompt, not by priors, and each of them read evidence you selected. That structure is good at rejecting misjudgements and blind to shared omissions.

So the filtered findings are not the verdict yet -- they are one side of an exchange. Run `{{ .n.reviewCrossModel }}` with them.

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
- [issue] — _lens: [lens], upheld by: [both sides / rebuttal failed]_

🟡 **Suggestions** (should consider)
- [suggestion] — _lens: [lens]_

⚖️ **Split** (the two models disagree — your call)
- [finding] — _raised by: [side]. Their position: [...]. The other side: [...]_

🚫 **Refuted** (raised, then withdrawn)
- [finding] — _refuted because: [...]_

📋 **Minor / Nitpicks** (confidence 50-79, titles only)
- [title]

🟢 **Good Practices**
- [positive observation]

**Details by Lens**

_Correctness_ · _Failure handling_ · _Tests_ · _Design_ · _Comments_ · _Conventions_ · _Security_

One block per lens that produced findings. Omit a lens that found nothing after
naming it in a single line, so the reader can tell it ran.

---

## Guardrails

- **Do not modify code** — this is a read-only review
- **Full diff** — every reviewer must receive the full diff, not a summary
- **Large diffs** — if over 500 lines changed, note at the top that the user may want to split the review
- **No findings** — if a lens finds no issues, state that briefly; do not fabricate issues
- **Spec alignment** — if the project has an active OpenSpec change, mention that `{{ .n.reviewSpec }}` can check requirement alignment
