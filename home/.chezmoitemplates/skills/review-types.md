{{ template "skills/code-review-context.md" . }}
{{ template "skills/code-review-scope.md" . }}
## Lens

One lens: `design.md`, under `~/.agent/reference/review-lenses/`.

Read the whole file, then answer only its **Invariants and encapsulation**
section for each type the diff adds or changes. The simplicity and
compatibility sections belong to `{{ .n.reviewLinus }}`, which runs this same
lens with the other emphasis — run one, not both.

If the diff adds or changes no type definitions, say so and stop. Do not
stretch the lens over code that has no types in it.

{{ template "skills/code-review-dispatch.md" . }}
## Output

Ratings are the exception to the no-scoring rule, and they stay inside this
report: they compare a type against itself, not findings against each other, so
nothing downstream ranks them.

---

**Type Design Review**

**Scope**: [reviewed what]
**Types analyzed**: [list of type names, or "none — no type definitions in this diff"]

For each type:

**`TypeName`**

_Invariants_
- [what must always be true, one line each]

_Ratings_
- Encapsulation: [n/10] — [can the invariant be broken from outside?]
- Invariant expression: [n/10] — [is it visible in the type, or only in prose?]
- Usefulness: [n/10] — [does it prevent a real bug, or just add ceremony?]
- Enforcement: [n/10] — [is an invalid instance constructible?]

_Recommendations_
- [concrete change, and the invalid state it stops being representable]

**Overall Assessment**
[summary, and which type most needs attention]

---

## Guardrails

- **Do not modify code** — this is a read-only review
- **Full diff** — the reviewer must receive the full diff
- **Types only** — do not report general code quality here; the other lenses own it
- **Weigh the cost** — a simpler type with fewer guarantees can beat an elaborate one; say when that is the answer
