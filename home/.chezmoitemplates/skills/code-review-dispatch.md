## Dispatching lenses

Each review perspective is a **lens** — a file under
`~/.agent/reference/review-lenses/` holding one question and nothing else. The
flow below names which lenses to run. Every lens is reviewed on its own, so
that its findings arrive uncontaminated by what another lens noticed.

Each lens review works from three things and nothing else:

- the **full diff**, never a summary of it;
- the lens file itself, read before the diff is judged;
- the reporting shape below.

{{/* axis: reader — how to spawn a parallel reviewer is a property of the tool executing this file, not of the code under review */ -}}
{{ if eq .n.tool "claude" -}}
Dispatch with the **Agent tool**, `subagent_type: reviewer`, all lenses in one
message so they run concurrently. That agent is read-only by construction: its
`tools` are `Read, Grep, Glob`, so it cannot edit the tree it is reviewing.
{{- else -}}
Work through the lenses one at a time. Before each, state which lens you are
opening; read its file; apply it to the diff; write its findings down before
opening the next. Do not carry a finding from one lens into another — the
separation is what keeps the same issue from being counted twice.

This review is read-only. Do not edit, stage, commit, or run anything that
changes the tree.
{{- end }}

## Reporting shape

Every reviewer returns findings in this shape, and nothing else:

- **What** — the defect, in one sentence.
- **Where** — `path:line`.
- **Trigger** — the input or state that produces it, concretely.
- **Consequence** — what happens instead of the right thing.
- **Fix** — the specific change, not a direction to explore.

A finding that cannot state a trigger and a consequence is a guess. Drop it
rather than reporting it with a hedge.

Findings are unscored at this stage. Severity is assigned once, later, on one
scale — a lens that arrives with its own ratings has broken the comparison, so
score nothing here.

Report in the language the user is writing in. A lens file being written in
English does not set the language of the report.
