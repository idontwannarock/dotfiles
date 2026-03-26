---
name: "codex-claude-parity"
description: "Use when the user wants a Claude Code-like workflow in Codex, especially for OpenSpec-style task framing, review checkpoints, git flow, or worklog reminders."
---

# Codex Claude Parity

Use this skill when the user asks to make Codex behave more like Claude Code, or when the task clearly benefits from the same structured workflow already documented in `~/.claude/CLAUDE.md`.

## Goal

Keep the spirit of the existing Claude workflow, but express it with Codex-native primitives:

- `AGENTS.md` for project guidance
- Codex skills instead of Claude slash commands
- Codex subagents instead of Claude agents
- Codex MCP config instead of Claude plugins

## Workflow

For non-trivial implementation work, confirm three things before deep execution:

1. Whether to use a structured workflow or just proceed directly.
2. Whether the task is small and bounded, or large and iterative.
3. Whether to pause after each checkpoint or auto-advance until a real decision point.

Skip this overhead for tiny edits, typos, one-line fixes, and straightforward questions.

## Mapping From Claude Concepts

- `OpenSpec + Superpowers` -> explicit planning, phased execution, and optional subagents
- `/git:sync` -> verify branch state and sync only when it is actually safe and useful
- `/code:review-*` -> switch into Codex review mode or perform a review-minded pass before completion
- Claude agents -> Codex subagents with scoped ownership
- Claude plugin MCP servers -> Codex MCP servers declared in `~/.codex/config.toml`

## Practical Rules

- Prefer one short plan before edits on non-trivial tasks.
- If the repo has `.claude/CLAUDE.md`, read it and treat it as legacy workflow context.
- If the repo has OpenSpec artifacts, preserve that workflow instead of bypassing it casually.
- When meaningful work is done, ask whether to record a worklog entry.
- Avoid copying Claude-specific command syntax into output unless the user explicitly wants cross-tool translation.

## Worklog

When any of these happen, ask whether the user wants to record a worklog:

- A meaningful task is completed
- A design or architecture direction is settled
- A commit is created
- The session is ending with substantive results

Skip the reminder for trivial edits or when already working in the worklog repo.
