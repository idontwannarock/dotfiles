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
| **New-branch workspace** (2c) | `git checkout -b <branch>` in the main repo; or `{{ .n.worktrees }}` if another workflow is active | always add a worktree off `main`: `git --git-dir=.bare worktree add -b add-<name> add-<name> main` (one branch per worktree). See `~/.agent/reference/bare-worktree/operating.md`. |
| **Registry / active-workflows path** (2b) | auto-derive: `git rev-parse --git-common-dir` → slug → `~/.agent/workflows/<slug>/active_workflows.md` | manual — Main Repo Path = `<repo>/main`, Active-workflows Path = `~/.agent/workflows/<slug>/active_workflows.md` (slug from `autoMemoryDirectory` key). See `~/.agent/reference/bare-worktree/claude-state.md` → "Workflow registry & project-memory path". |
| **Finishing** (end of Step 3) | `{{ .n.finishing }}` as written | rebase → `git merge --ff-only` from the `main/` worktree → dispose worktree + branch. See `~/.agent/reference/bare-worktree/operating.md` → "Finishing / merging a branch back". Do **not** use the skill's in-place Step 5/6. |

### 2a. Sync main

Run `{{ .n.gitSync }}` unless already on a worktree.

### 2b. Resolve workflow registry

Look up `~/.agent/workflow-registry.md` for this repo's main repo path and active-workflows path. If no entry: derive the repo slug from `git rev-parse --git-common-dir` (slugify the result with `/`→`-`), set active-workflows path to `~/.agent/workflows/<repo-slug>/active_workflows.md`, add a row. Registry is per-machine, not synced.

> **Architecture-specific:** follow the **Registry / active-workflows path** row of the dispatch table above for your `ARCH`. Under `bare-worktree` the auto-derivation is wrong — set the row by hand per `claude-state.md`.

### 2c. Check active workflows

Read `~/.agent/workflows/<repo-slug>/active_workflows.md` (slug derived from `git rev-parse --git-common-dir` as above). Clean stale entries (missing worktree paths, deleted branches).

| State | Action |
|-------|--------|
| **None active** | Work directly in main repo: `git checkout -b <new-branch>`. Register row with Type=`main`. |
| **Any active/paused** | Read `~/.agent/reference/dev-workflow-isolation.md` — requires worktree. |

> **Architecture-specific:** create the workspace per the **New-branch workspace** row of the dispatch table above. Under `ARCH=bare-worktree` the "None active → `checkout -b` in main" row does **not** apply — always add a worktree off `main`, Type=`worktree`.

The `active_workflows.md` row format:

| Change | Branch | Path | Type | Current Step | Status | Last Updated |

- **Path**: actual working directory (main repo or worktree path)
- **Type**: `main` or `worktree`
- **Current Step**: a tool-neutral semantic label (e.g. `apply-change done`, `review`) — this file is shared across tools, so never write a sigil'd skill token (`{{ .n.sk }}openspec-…`); the resuming tool re-derives the token from its own name-map.
- **Status**: `active` or `paused`

Update Current Step + Last Updated after each skill completes. Set Status to `paused` when switching workflows. Remove the row after `{{ .n.finishing }}`.

## Step 3: Run the Core Flow

OpenSpec uses skill-based delivery — invoke by skill name (e.g. `{{ .n.sk }}openspec-new-change`),
NOT slash commands (`/opsx:*`). Skills are agent- and subagent-invocable and portable to
Codex; slash commands are user-typed UI only and unavailable to dispatched subagents.

### Small workflow

```
{{ .n.ensureScript }}
→ {{ .n.sk }}openspec-new-change → {{ .n.sk }}openspec-continue-change (loop until artifacts ready)
→ {{ .n.sk }}openspec-apply-change → openspec validate
→ [{{ .n.sk }}openspec-sync-specs — ask if implementation drifted from specs] → {{ .n.sk }}openspec-archive-change
→ {{ .n.gitCommit }} → {{ .n.reviewQuick }}
→ Fixes needed? → Confirm scope, start a new change round (same branch/worktree, from {{ .n.sk }}openspec-new-change)
→ No fixes → {{ .n.finishing }} → [{{ .n.gitCleanGone }}]
```

### Large workflow

```
{{ .n.ensureScript }}
→ {{ .n.brainstorm }}   (design → ~/.local/share/superpowers/<repo>/specs/, NOT docs/)
→ {{ .n.sk }}openspec-new-change → {{ .n.sk }}openspec-continue-change   (proposal + design.md + tasks.md into openspec/)
→ [{{ .n.writingPlans }} — only if implementation needs choreography beyond
   tasks.md (multi-session, executing-plans/subagent handoff); else tasks.md IS the plan]
→ {{ .n.sk }}openspec-apply-change
→ {{ .n.verification }} (run tests / verify commands — hard evidence)
→ {{ .n.sk }}openspec-verify-change (three-dimension spec/code coherence report)
→ openspec validate → {{ .n.sk }}openspec-sync-specs → {{ .n.sk }}openspec-archive-change
→ {{ .n.gitCommit }} → {{ .n.reviewFull }}
→ Fixes needed? → Confirm scope, start a new change round
→ No fixes → {{ .n.finishing }} → [{{ .n.gitCleanGone }}]
```

> **Finishing is architecture-specific** (dispatch table, **Finishing** row): under
> `ARCH=bare-worktree`, the `finishing-a-development-branch` step does **not** use
> the skill's in-place checkout/cleanup — merge + dispose follow
> `~/.agent/reference/bare-worktree/operating.md` ("Finishing / merging a branch
> back"). Disposing the worktree + branch and removing the `active_workflows.md`
> row are part of finishing, not manual afterwork.

## Code Review Commands

{{ .n.reviewList }}
