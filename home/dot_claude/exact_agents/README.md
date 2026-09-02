Personal agents for Claude Code, deployed by chezmoi from
`home/dot_claude/exact_agents/`.

`exact_agents/` is chezmoi-exclusive: deleting a file here removes it from
`~/.claude/agents/` on the next apply. `exact_` is **single-level**, so any
subdirectory added here needs the prefix too (`exact_engineering/`), or
deletions inside it are silently never pruned.

# What is here

One agent: `reviewer`. It is read-only by construction — `tools: Read, Grep,
Glob` — and the `review-*` flows dispatch it once per lens.

It is not meant to be routed to directly, and its description says so. The
flows name it; you do not.

# Why there is only one

An agent's `description` is preloaded into every session's system prompt, so
the model can decide when to route to it. Only the body is lazy. An agent that
is never invoked therefore still costs tokens on every session, and the cost
scales with how well its description is written.

This directory once held 31 agents costing roughly 14k tokens per session, 24
of which nothing referenced. The seven that were referenced held the review
perspectives for the `/code:review-*` commands — real content, in the wrong
place: preloaded whether or not a review ran, and invisible to Codex, which has
no agents at all.

Those seven are now lens files under `~/.agent/reference/review-lenses/`, in
the tool-agnostic tree both Claude and Codex read. A plain file costs nothing
until something opens it, and the flows on both sides name the same paths.

What did not survive the move: five incompatible severity scales in one report,
three lenses asserting another project's house rules (Sentry error ids, React
component conventions), and a "read-only review" guardrail that was prose only —
every one of those seven agents could write to the tree it was reviewing.

# Reference

- [contains-studio/agents](https://github.com/contains-studio/agents) — where
  the retired 24 came from
- [kingkongshot/prompts](https://github.com/kingkongshot/prompts)
