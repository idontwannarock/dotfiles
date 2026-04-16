---
name: review-codex
description: Codex cross-model code review — use OpenAI Codex for an independent second opinion (standard or adversarial mode)
---

## Context

First, gather context by running these commands:

- `git status --short` — working tree state
- `git branch --show-current` — current branch

## Arguments

Parse arguments:

- First word is `adversarial` or `adv` → adversarial mode, remove that word, rest becomes codex args
- Otherwise → standard mode

Convert arguments for Codex (uses `--base` and `--scope`, does not accept PR numbers directly):

1. Number (PR number) → add `--base main`
2. Contains `..` → extract the ref before `..` as `--base <ref>`
3. Branch name → `--base main`
4. No arguments → no extra args (Codex defaults to working tree)
5. Already has `--base` or `--scope` → pass through as-is

Always append `--wait` (unless already present or `--background` is specified).

## Task

Invoke the corresponding Codex review skill:

- **Standard mode** → `codex:review` with converted args
- **Adversarial mode** → `codex:adversarial-review` with converted args

## Output

Present the Codex review output directly. Do not add extra summary or commentary.

If the review runs in background, inform the user they can check progress with `codex:status` and results with `codex:result`.

## Guardrails

- **Do not modify code** — this is a read-only review
- **Argument conversion** — Codex cannot directly read PR diffs; it reviews working tree or branch diffs
- **PR limitation** — if a PR number is given, note that Codex reviews the current working tree/branch changes, not the PR diff directly
