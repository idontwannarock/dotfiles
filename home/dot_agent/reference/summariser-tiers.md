---
type: Reference
title: Summariser tiers
description: "Which agent handles a body of text, chosen by its size, so a skill body can name a tier without naming a model."
---

# Summariser tiers

Read this when a skill has measured some text and needs to decide who summarises it.

A skill body says `medium`. This file says what `medium` costs today. The two change
on different clocks: the thresholds follow how much text a summary can absorb before it
flattens, and the model column follows whatever is current and cheapest. Keeping the
model names here means a new model release edits one table instead of every skill.

## Why this is a table and not a branch

The agent that ends up doing the work is a **runtime** value. Which one a skill
dispatches is decided long after the skill file renders, so a render-time branch cannot
know it — a branch can only ever ask about the reader. Content about another agent must
therefore be a table covering the kinds. `skill-name-map-axis.test.sh` enforces that
distinction on the shared skill bodies; this file is the table those bodies read.

## The tiers

Thresholds are in estimated tokens of the text to be summarised, not of the source file.

| Tier | Size | What the tier is for |
|------|------|----------------------|
| `small` | under 8K | One short piece. The structure is obvious and the facts are few. |
| `medium` | 8K to 40K | Long enough that a small model starts dropping the numbers and named examples. |
| `large` | over 40K | Long enough that a single pass flattens it. Worth a second opinion. |

## Who runs each tier

| Tier | Claude Code | Codex |
|------|-------------|-------|
| `small` | `Agent`, `model: haiku` | `spawn_agent`. Leave `model` unset. |
| `medium` | `Agent`, `model: sonnet` | `spawn_agent`. Leave `model` unset. |
| `large` | A counterpart of a different kind; fall back to `Agent`, `model: opus` | `spawn_agent` in named passes. Leave `model` unset. |

The two columns do different work, and the difference is not cosmetic. Under Claude Code
the tier picks the model. Under Codex a spawned agent **inherits the caller's model** and
its own tool description says not to set `model` unless the user asked for one, so the tier
picks how much care the pass gets, not which model runs it. Do not port the Claude column
across by setting `model` on a Codex spawn.

Current Claude model ids, for the `summarized_by` field a caller records: Haiku 4.5 is
`claude-haiku-4-5-20251001`, Sonnet 5 is `claude-sonnet-5`, Opus 5 is `claude-opus-5`.
Record the id that actually ran, never the tier name — the tier is a routing decision and
the id is the fact.

For the `large` tier under Claude Code, `cross-model-counterparts.md` holds each kind's
readiness probe and launch arguments. That file is written for code review, where the
counterpart runs in a herdr pane against a repo. Summarising one file needs none of that
choreography: a non-interactive run pointed at the file's directory is enough. Take the
probe and the authentication facts from it; leave the pane handling behind.

## Verified, and when

Codex 0.153.4 has `spawn_agent`, and its `multi_agent` feature flag ships enabled.
Verified 2026-09-10 by reading the shipped binary's own tool description, not from docs
or memory. An earlier note in this repo said the Codex subagent API was unverified; that
was a gap, and a later reading turned it into "Codex cannot dispatch", which was wrong.
Re-probe with `codex features list` and the binary's strings when the version moves,
rather than trusting this paragraph.

`~/.codex/agents/` holds agent definitions. It does not exist on this machine yet, so a
spawn here uses the default agent.

## What a caller must not do

- Do not read the tier as a ceiling. Override it when the user asks for depth, or when
  the summary feeds a decision rather than a reading list. State the override and why.
- Do not let a small model decide it needs a bigger one. The measurement happens before
  dispatch, on purpose: an agent asking for a promotion mid-task cannot be checked.
