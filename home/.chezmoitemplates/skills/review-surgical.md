{{ template "skills/code-review-context.md" . }}
{{ template "skills/code-review-scope.md" . }}
## Lenses

A deliberate subset of `{{ .n.reviewFull }}` — the two lenses that pay for
themselves on almost every diff. Reach for the full set when the change is
risky, touches a trust boundary, or is going out to other people.

| Lens | File | The question |
|------|------|--------------|
| correctness | `correctness.md` | Does this code do the wrong thing? |
| design | `design.md` | Is the structure right — and could it be simpler? |

Not run here, and what you give up: `failure-handling` (silent failures),
`tests` (regression coverage), `security` (trust boundaries), `comments`,
`conventions`. Say so in the report — a narrow review presented as a whole one
is worse than no review.

{{ template "skills/code-review-dispatch.md" . }}
## Output

No confidence pass. Two lenses produce few enough findings to read whole, and
the filter costs a round trip that the quick review exists to avoid. Report
everything both lenses returned.

---

**Surgical Review**

**Scope**: [reviewed what — staged / unstaged / HEAD / branch diff / PR #N]
**Diff size**: [N files changed, +X/-Y lines]
**Lenses**: correctness, design — _not run: failure-handling, tests, security, comments, conventions_

🔴 **Critical Issues** (must fix)
- [issue] — _lens: [lens]_

🟡 **Suggestions** (should consider)
- [suggestion] — _lens: [lens]_

✂️ **Simplification Opportunities**
- [what can be simplified, and the special case or branch that disappears]

🟢 **Good Practices** (well done)
- [positive observation]

---

## Guardrails

- **Do not modify code** — this is a read-only review
- **Full diff** — every reviewer must receive the full diff
- **No findings** — if a lens finds no issues, state that briefly
- **Unscored** — findings here carry no confidence score; do not invent one
