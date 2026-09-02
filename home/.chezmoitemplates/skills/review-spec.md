{{ template "skills/code-review-context.md" . }}
## Step 1: Select the OpenSpec change

In this order:

1. The first word of the arguments is a change name → use it
2. The conversation names a change → infer it
3. Exactly one active change → take it
4. Several, or unclear → run `openspec list --json` and ask the user to choose

Then declare: `Using change: <name>`.

## Step 2: Load artifacts

```bash
openspec instructions apply --change "<name>" --json
```

Read every artifact listed under `contextFiles` — proposal, specs, design,
tasks. Record any that are missing; the report has to say which dimensions went
unchecked rather than quietly narrowing.

## Step 3: Get the diff

With the change name removed from the arguments, apply the standard order:

{{ template "skills/code-review-scope.md" . }}
## Step 4: Dispatch

This flow does not use the review lenses. Every question here is asked
*relative to the spec* — whether the code matches what was agreed — and no lens
holds the artifacts that make that judgeable. General code quality is
`{{ .n.reviewFull }}`'s job; do not repeat it here.

Each reviewer receives the **full diff** and the **full artifact text**, plus
one of the briefs below.

| Reviewer | Brief |
|----------|-------|
| Requirement alignment | For each requirement: implemented, partially implemented, missing, or diverged. Then the reverse direction — implementation with no requirement behind it. Quote the requirement you are judging against. |
| Design adherence | Does the implementation follow the architecture the design document settled on? Is it over- or under-built **relative to what the requirements asked for** — not in the abstract? |
| Scenario coverage | For each scenario in the specs: does a test exercise it, and does that test assert the behaviour the scenario describes rather than merely running the code path? |

{{/* axis: reader — how to spawn a parallel reviewer is a property of the tool executing this file */ -}}
{{ if eq .n.tool "claude" -}}
Dispatch with the **Agent tool**, `subagent_type: reviewer`, all three in one
message so they run concurrently.
{{- else -}}
Work through the three briefs one at a time, writing each set of findings down
before starting the next. This review is read-only.
{{- end }}

## Output

---

**Spec-Aware Code Review**

**Change**: <change-name>
**Artifacts loaded**: proposal / specs / design / tasks — [mark which are present and which are missing]
**Scope**: [reviewed what — staged / PR / branch diff]
**Diff size**: [N files changed, +X/-Y lines]

**Requirement Alignment**

| Requirement | Status | Notes |
|-------------|--------|-------|
| [req] | Implemented / Partial / Missing / Diverged | [detail] |

🔴 **Gaps** (required, not delivered)
- [what is missing, which requirement, what it would take]

🟡 **Divergences** (delivered, but not what was agreed)
- [spec says X, code does Y, and which one is probably wrong]

🟠 **Over-scope** (delivered, never asked for)
- [what was added, and whether to keep it or cut it]

**Design Adherence**
- [design decision] → [followed / diverged / improved on] — [detail]

**Scenario Test Coverage**

| Scenario | Test exists | Asserts the intent |
|----------|-------------|--------------------|
| [scenario] | Yes / No | Yes / Partial / No |

🟢 **Well Aligned**
- [where spec and code genuinely match]

---

## Guardrails

- **Do not modify code** — this is a read-only review
- **Full context** — every reviewer receives the full diff *and* the full artifacts
- **Missing artifact** — skip that dimension and say so in the report; do not guess at what it would have said
- **No OpenSpec change** — if the project has none active, say so and point at `{{ .n.reviewFull }}`
- **Spec alignment only** — do not repeat general code quality review here
