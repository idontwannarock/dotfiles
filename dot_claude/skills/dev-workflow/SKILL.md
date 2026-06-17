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

Detect the repo architecture **once** up front — it decides the mechanics at
three points below (new-branch workspace, registry derivation, finishing). The
abstract flow is identical for both architectures; only the rows of the dispatch
table differ.

```bash
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
case "$(basename "$GIT_COMMON")" in
  .bare) ARCH=bare-worktree ;;
  *)     ARCH=normal ;;
esac
```

Follow the column for your `ARCH` at each marked step:

| Divergence point | `ARCH=normal` | `ARCH=bare-worktree` |
|------------------|---------------|----------------------|
| **New-branch workspace** (2c) | `git checkout -b <branch>` in the main repo; or `superpowers:using-git-worktrees` if another workflow is active | always add a worktree off `main`: `git --git-dir=.bare worktree add -b add-<name> add-<name> main` (one branch per worktree). See `~/.agent/reference/bare-worktree/operating.md`. |
| **Registry / project-memory path** (2b) | auto-derive: `git rev-parse --git-common-dir` + cwd-slug project path | manual — Main Repo Path = `<repo>/main`, Project Memory Path = the repo's `autoMemoryDirectory`. See `~/.agent/reference/bare-worktree/claude-state.md` → "Workflow registry & project-memory path". |
| **Finishing** (end of Step 3) | `superpowers:finishing-a-development-branch` as written | rebase → `git merge --ff-only` from the `main/` worktree → dispose worktree + branch. See `~/.agent/reference/bare-worktree/operating.md` → "Finishing / merging a branch back". Do **not** use the skill's in-place Step 5/6. |

### 2a. Sync main

Run `git:sync` unless already on a worktree.

### 2b. Resolve workflow registry

Look up `~/.claude/workflow-registry.md` for this repo's main repo path and project memory path. If no entry: derive with `git rev-parse --git-common-dir`, compute the project memory path, add a row. Registry is per-machine, not synced.

> **Architecture-specific:** follow the **Registry / project-memory path** row of the dispatch table above for your `ARCH`. Under `bare-worktree` the auto-derivation is wrong — set the row by hand per `claude-state.md`.

### 2c. Check active workflows

Read `active_workflows.md` from the project memory directory. Clean stale entries (missing worktree paths, deleted branches).

| State | Action |
|-------|--------|
| **None active** | Work directly in main repo: `git checkout -b <new-branch>`. Register row with Type=`main`. |
| **Any active/paused** | Read `references/isolation.md` — requires worktree. |

> **Architecture-specific:** create the workspace per the **New-branch workspace** row of the dispatch table above. Under `ARCH=bare-worktree` the "None active → `checkout -b` in main" row does **not** apply — always add a worktree off `main`, Type=`worktree`.

The `active_workflows.md` row format:

| Change | Branch | Path | Type | Current Step | Status | Last Updated |

- **Path**: actual working directory (main repo or worktree path)
- **Type**: `main` or `worktree`
- **Status**: `active` or `paused`

Update Current Step + Last Updated after each skill completes. Set Status to `paused` when switching workflows. Remove the row after `superpowers:finishing-a-development-branch`.

## Step 3: Run the Core Flow

OpenSpec uses skill-based delivery — invoke by skill name (e.g. `openspec-new-change`),
NOT slash commands (`/opsx:*`). Skills are agent- and subagent-invocable and portable to
Codex; slash commands are user-typed UI only and unavailable to dispatched subagents.

### Small workflow

```
~/.claude/skills/dev-workflow/scripts/ensure-openspec.sh
→ openspec-new-change → openspec-continue-change (loop until artifacts ready)
→ openspec-apply-change → openspec validate
→ [openspec-sync-specs — ask if implementation drifted from specs] → openspec-archive-change
→ git:commit → code:review-quick
→ Fixes needed? → Confirm scope, start a new change round (same branch/worktree, from openspec-new-change)
→ No fixes → superpowers:finishing-a-development-branch → [git:clean-gone]
```

### Large workflow

```
~/.claude/skills/dev-workflow/scripts/ensure-openspec.sh
→ superpowers:brainstorming   (design → ~/.local/share/superpowers/<repo>/specs/, NOT docs/)
→ openspec-new-change → openspec-continue-change   (proposal + design.md + tasks.md into openspec/)
→ [superpowers:writing-plans — only if implementation needs choreography beyond
   tasks.md (multi-session, executing-plans/subagent handoff); else tasks.md IS the plan]
→ openspec-apply-change
→ superpowers:verification-before-completion (run tests / verify commands — hard evidence)
→ openspec-verify-change (three-dimension spec/code coherence report)
→ openspec validate → openspec-sync-specs → openspec-archive-change
→ git:commit → code:review-full
→ Fixes needed? → Confirm scope, start a new change round
→ No fixes → superpowers:finishing-a-development-branch → [git:clean-gone]
```

> **Finishing is architecture-specific** (dispatch table, **Finishing** row): under
> `ARCH=bare-worktree`, the `finishing-a-development-branch` step does **not** use
> the skill's in-place checkout/cleanup — merge + dispose follow
> `~/.agent/reference/bare-worktree/operating.md` ("Finishing / merging a branch
> back"). Disposing the worktree + branch and removing the `active_workflows.md`
> row are part of finishing, not manual afterwork.

## Code Review Commands

`code:review-quick`, `code:review-full`, `code:review-spec`, `code:review-linus`,
`code:review-security`, `code:review-types`.
