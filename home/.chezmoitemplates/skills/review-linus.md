{{ template "skills/code-review-context.md" . }}
{{ template "skills/code-review-scope.md" . }}
## Lens

One lens: `design.md`, under `~/.agent/reference/review-lenses/`.

It asks whether the structure is right and whether it could be simpler —
special cases that a better data structure would erase, complexity that buys
nothing, invariants left to discipline, and compatibility with what already
depends on this code.

This flow and `{{ .n.reviewTypes }}` run the same lens and differ only in the
report: this one delivers a verdict on the change as a whole, that one a
per-type breakdown. Run one, not both.

{{ template "skills/code-review-dispatch.md" . }}
## Output

Deliver it in the register the lens deserves: direct, specific, unsentimental.
Criticise the code, never the person who wrote it, and never soften a real
finding to be pleasant. Praise is worth something only when it is rare.

---

**Design Review**

**Scope**: [reviewed what]

**Verdict**: [one sentence — direct, unforgiving but fair]

**Structure & Data Model**
[what the core data is, who owns it, and whether the shape fits the problem]

**Unnecessary Complexity**
[what is over-built, and what removing it costs]

**Special Cases That Should Disappear**
[the branch, and the structural change that erases it — not just that it exists]

**Invariants**
[what must always be true, and whether anything but discipline enforces it]

**Compatibility**
[what already depends on this, and what a caller outside this repo would see break]

**What's Actually Good**
[design decisions worth keeping]

---

## Guardrails

- **Do not modify code** — this is a read-only review
- **Full diff** — the reviewer must receive the full diff
- **Earn every suggestion** — name the branch that collapses or the invalid state that stops being representable; a restructuring that only moves code sideways is not an improvement
- **Pragmatism wins** — if the honest answer is "leave it", say that

