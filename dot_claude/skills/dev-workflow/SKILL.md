---
name: dev-workflow
description: Use when receiving any implementation task — adding features, fixing bugs, refactoring code, or modifying behavior beyond trivial one-line changes. Also use when the user asks about the development workflow, process, or OpenSpec flow. Handles requests in any language (e.g. 加功能、修 bug、重構). Orchestrates the full OpenSpec + Superpowers lifecycle: workflow selection, worktree isolation decisions, spec → implement → review → merge. Make sure to invoke this skill whenever a real implementation task arrives, even if the user doesn't explicitly ask for a "workflow" — skipping it risks losing spec tracking and review gates.
---

# Development Workflow

Structured flow for real implementation work — specs, tracking, review gates.
Skip entirely for trivial tasks (typos, one-line changes, simple Q&A).

## Step 1: Confirm Workflow

Ask once:

| Workflow | When to use |
|----------|------------|
| **Small** | Well-scoped tasks, modest changes |
| **Large** | Complex tasks needing multi-round discussion |
| **Skip** | Proceed without OpenSpec — standard approach |

Skip → stop here and proceed with standard development.

## Step 2: Locate or Start a Workflow

### 2a. Sync main

Run `git:sync` unless already on a worktree.

### 2b. Resolve workflow registry

Look up `~/.claude/workflow-registry.md` for this repo's main repo path and project memory path. If no entry: derive with `git rev-parse --git-common-dir`, compute the project memory path, add a row. Registry is per-machine, not synced.

> **Bare+worktree repos**: registry auto-derivation is wrong here — set the row by hand. See `~/.agent/reference/bare-worktree/claude-state.md` → "Workflow registry & project-memory path".

### 2c. Check active workflows

Read `active_workflows.md` from the project memory directory. Clean stale entries (missing worktree paths, deleted branches).

| State | Action |
|-------|--------|
| **None active** | Work directly in main repo: `git checkout -b <new-branch>`. Register row with Type=`main`. |
| **Any active/paused** | Read `references/isolation.md` — requires worktree. |

> **Bare+worktree repos**: the "None active → `checkout -b` in main" row doesn't apply — always add a worktree off `main` (one branch per worktree). See `~/.agent/reference/bare-worktree/index.md`.

The `active_workflows.md` row format:

| Change | Branch | Path | Type | Current Step | Status | Last Updated |

- **Path**: actual working directory (main repo or worktree path)
- **Type**: `main` or `worktree`
- **Status**: `active` or `paused`

Update Current Step + Last Updated after each skill completes. Set Status to `paused` when switching workflows. Remove the row after `superpowers:finishing-a-development-branch`.

## Step 3: Run the Core Flow

OpenSpec uses skill-based delivery — invoke by skill name, not slash commands.

### Small workflow

```
~/.claude/skills/dev-workflow/scripts/ensure-openspec.sh
→ openspec-propose
→ openspec-apply-change → openspec validate → openspec-archive-change
→ git:commit → code:review-quick
→ Fixes needed? → Confirm scope, start a new change round (same branch/worktree, from openspec-propose)
→ No fixes → superpowers:finishing-a-development-branch → [git:clean-gone]
```

### Large workflow

```
~/.claude/skills/dev-workflow/scripts/ensure-openspec.sh
→ superpowers:brainstorming   (design → ~/.local/share/superpowers/<repo>/specs/, NOT docs/)
→ openspec-propose            (proposal + design.md + tasks.md into openspec/)
→ [superpowers:writing-plans — only if implementation needs choreography beyond
   tasks.md (multi-session, executing-plans/subagent handoff); else tasks.md IS the plan]
→ openspec-apply-change
→ superpowers:verification-before-completion → openspec validate → openspec-archive-change
→ git:commit → code:review-full
→ Fixes needed? → Confirm scope, start a new change round
→ No fixes → superpowers:finishing-a-development-branch → [git:clean-gone]
```

## Code Review Commands

`code:review-quick`, `code:review-full`, `code:review-spec`, `code:review-linus`,
`code:review-security`, `code:review-types`.
