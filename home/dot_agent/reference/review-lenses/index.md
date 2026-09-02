---
okf_version: "0.2"
---

# Review lenses

One file per review perspective, read on demand by the `review-*` flows. Plain
reference files, not agents and not skills: nothing here is preloaded into a
session, and nothing here is listed in a tool's routing table. A flow names the
path, the reviewer reads it.

That is the whole reason this tree holds them. An agent definition and a skill
both pay for their existence on every session, because the model has to see
their description to know when to route to one. A lens is chosen by a flow that
already decided, so it can stay on disk until the moment it is needed.

## The set

Each lens answers exactly one question. They were split so that a finding
belongs to one of them, not two.

| Lens | The question |
| --- | --- |
| [correctness](correctness.md) | Does this code do the wrong thing? |
| [failure-handling](failure-handling.md) | When something goes wrong, does anyone find out? |
| [tests](tests.md) | If this change broke, would a test go red? |
| [design](design.md) | Is the structure right — and could it be simpler? |
| [comments](comments.md) | Does the prose still describe the code? |
| [conventions](conventions.md) | Does this follow the rules this repo wrote down? |
| [security](security.md) | Can someone make this do something it should not? |

Boundaries that are easy to get wrong:

- A bug is `correctness`. What the code does *after* the bug — hide it, fall
  back, log nothing — is `failure-handling`.
- Structure that is ugly but behaves correctly is `design`, never
  `correctness`.
- A rule the repo wrote down is `conventions`. A rule you would prefer is not a
  finding at all.
- `design` covers both simplicity and type invariants. They are one lens
  because most special cases come from a data model that forced them.

## What a lens does not contain

No scoring scale, no report format, no read-only instruction, no persona. The
flow that dispatches the lens supplies all of that, once, so that every lens in
a run is scored on the same scale and reports in the same shape. Adding a
second scale to a lens file breaks the flow's ability to rank findings against
each other.

Nor does a lens assert another project's standards. Where a judgement depends
on local rules — logging, test shape, naming — the lens says to read this
repo's `CLAUDE.md` / `AGENTS.md` and its neighbouring code.

## Adding one

Only when a finding has nowhere to go. A new lens that overlaps an existing one
produces the same issue twice under two names, and the flow has no way to
merge them. Prefer sharpening an existing lens.

The flows that dispatch these live in `.chezmoitemplates/skills/review-*.md`;
`tests/review-lens-refs.test.sh` checks that every path they name exists.
