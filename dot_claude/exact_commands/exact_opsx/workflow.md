---
description: >
  Use when receiving any implementation task — adding features, fixing bugs, refactoring code,
  or modifying behavior beyond trivial one-line changes. Also use when the user asks about the
  development workflow, process, or OpenSpec flow. Handles requests in any language
  (e.g. 加功能、修 bug、重構). Orchestrates the full OpenSpec + Superpowers lifecycle:
  workflow selection (small/large/skip), worktree isolation decisions, spec → implement → review → merge.
---

# OpenSpec + Superpowers Development Workflow

This skill orchestrates the full development lifecycle. It replaces ad-hoc coding with a structured
flow that produces specs, tracks changes, and ensures review — while staying lightweight enough to
skip entirely for trivial tasks.

## Step 1: Confirm Workflow and Progression Mode

Ask the user **once** before starting:

> 1. Workflow: **OpenSpec Small** / **OpenSpec Large** / **Skip**
> 2. Progression: **Step-by-step** / **Auto-advance** (OpenSpec workflows only)

| Workflow | When to use |
|----------|------------|
| **Small** | Well-scoped tasks, modest changes |
| **Large** | Complex tasks needing multi-round discussion |
| **Skip** | Proceed without OpenSpec — standard approach |
| _(Trivial)_ | Typo fixes, one-line changes, simple Q&A — skip this skill entirely, don't ask |

| Progression | Behavior |
|-------------|----------|
| **Step-by-step** | Pause after each skill for user to say "continue" |
| **Auto-advance** | Move to the next step automatically, pause only at key decision points |

Progression mode determines the opsx command variant:
- **Auto-advance** → `opsx:propose` (generates and confirms spec in one step)
- **Step-by-step** → `opsx:new` + `opsx:continue` (user reviews at each stage)

If the user picks **Skip**, stop here and proceed with standard development.

## Step 2: Sync and Decide Isolation Strategy

### 2a. Sync main

Run `git:sync` to ensure main is up-to-date.
Skip this if the current session is already on a worktree (main isn't the working directory).

### 2b. Resolve the workflow registry

Look up `~/.claude/workflow-registry.md` for this repo's main repo path and project memory path.

| Repo Name | Main Repo Path | Project Memory Path |
|-----------|---------------|---------------------|

If no entry exists:
1. Run `git rev-parse --git-common-dir` to derive the main repo path
2. Compute the project memory path from it
3. Add the entry to the registry

Each machine maintains its own registry; it is not synced across machines.

### 2c. Check active workflows

Read `active_workflows.md` from the project memory directory.

**Cleanup first** — remove stale entries:
- Worktree entries where the path no longer exists on disk
- Main repo entries where the branch no longer exists (`git branch --list <branch>`)

**Then decide**:

| Active workflows state | Action |
|----------------------|--------|
| **None active** (empty after cleanup) | Work directly in main repo: `git checkout -b <new-branch>` |
| **Any active or paused** | Invoke `superpowers:using-git-worktrees` to create an isolated worktree |

The reason for this rule: a single git working directory can only have one branch checked out at a
time. If another workflow is in progress (even paused), working directly in the main repo risks
conflicts when either session tries to merge, rebase, or switch branches. Worktree isolation
eliminates this entire class of problems.

**If active workflows exist**, show them to the user and ask: resume an existing one, or start a new one?

### 2d. Register the new workflow

Add a row to `active_workflows.md` immediately after branch creation or worktree setup:

| Change | Branch | Path | Type | Current Step | Status | Last Updated |
|--------|--------|------|------|--------------|--------|--------------|

- **Path**: the actual working directory (main repo path or worktree path)
- **Type**: `main` or `worktree`
- **Status**: `active`

## Step 3: Run the Core Flow

### Small workflow

```
ensure-openspec
→ opsx:propose (or opsx:new + opsx:continue)
→ opsx:apply → openspec validate → opsx:archive
→ git:commit → code:review-quick
→ Needs fixes? → Confirm scope, start a new change round (same branch/worktree, from opsx step)
→ No fixes needed → superpowers:finishing-a-development-branch → [git:clean-gone]
```

### Large workflow

```
ensure-openspec
→ superpowers:brainstorming
→ opsx:propose (or opsx:new + opsx:continue)
→ superpowers:writing-plans → opsx:apply
→ superpowers:verification-before-completion → openspec validate → opsx:archive
→ git:commit → code:review-full
→ Needs fixes? → Confirm scope, start a new change round (same branch/worktree, from opsx step)
→ No fixes needed → superpowers:finishing-a-development-branch → [git:clean-gone]
```

## Git Integration

These behaviors happen automatically at specific points in the flow:

| When | What | Behavior |
|------|------|----------|
| Flow start | `git:sync` | Auto-run (skip if already on a worktree) |
| After isolation decided | Update registry + active workflows | Auto-run for both main repo and worktree |
| After `opsx:archive` | `git:commit` | Propose commit, execute after user confirms |
| After review passes | `superpowers:finishing-a-development-branch` | Rebase on main before merge; pause on conflicts |
| After merge | `git:clean-gone` | Suggest cleanup of merged local branches and worktrees |
| Flow complete | Update active workflows | Remove the entry for this workflow |

## Active Workflows Reference

### Update triggers

| Event | Action |
|-------|--------|
| Branch created or worktree set up | Add a new row |
| Each skill completes | Update Current Step + Last Updated |
| Switching to another workflow | Set Status to `paused` |
| Flow complete (after finishing-a-development-branch) | Remove the row |

### Session start behavior

Every session receiving a task should read `active_workflows.md` first:
1. Clean up stale entries (missing worktree paths, deleted branches)
2. If active workflows remain → show them, ask user to resume or start new
3. If none → proceed to Step 1 normally

## Spec File Location

Design specs from `superpowers:brainstorming` stay in the conversation — do **not** write them to
`docs/superpowers/specs/`. Formal specs are produced by opsx (`opsx:propose` or `opsx:new`) into the
`openspec/` directory.

## Optional Extensions

These skills are pulled in automatically when the situation calls for them:
`superpowers:test-driven-development`, `superpowers:systematic-debugging`,
`superpowers:using-git-worktrees`, `superpowers:requesting-code-review`, etc.

Code review commands: `code:review-quick` (fast), `code:review-full` (4-agent comprehensive),
`code:review-spec` (requirements alignment), `code:review-linus` (architecture),
`code:review-security` (security), `code:review-types` (type design).

> Full list and usage scenarios: read `~/.claude/reference.md`
