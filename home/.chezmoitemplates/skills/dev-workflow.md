# Development Workflow

Structured flow for real implementation work — specs, tracking, review gates.
Skip entirely for trivial tasks (typos, one-line changes, simple Q&A).

## Step 0: Bug Tasks Diagnose First

For bug reports and performance regressions, run `{{ .n.diagnose }}` BEFORE
choosing a workflow: build a feedback loop, minimize, confirm the root cause.
The confirmed root cause becomes the change proposal's `## Why`. Then continue
with Step 1 (usually Small).

## Step 1: Confirm Workflow

Ask once:

| Workflow | When to use |
|----------|------------|
| **Small** | Well-scoped tasks, modest changes |
| **Large** | Complex tasks needing multi-round discussion |
| **Skip** | Proceed without OpenSpec — standard approach |

Skip → stop here and proceed with standard development.

## Step 2: Locate or Start a Workflow

Detect the repo architecture **once** up front — it decides the workspace and
registry mechanics below. The abstract flow is identical for both architectures.

```bash
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
case "$(basename "$GIT_COMMON")" in
  .bare) ARCH=bare-worktree ;;
  *)     ARCH=normal ;;
esac
```

| Divergence point | `ARCH=normal` | `ARCH=bare-worktree` |
|------------------|---------------|----------------------|
| **New-branch workspace** (2c) | `git checkout -b <branch>` in the main repo; or `{{ .n.worktree }}` if another workflow is active | always create via `{{ .n.worktree }}` (worktree off `main`, one branch per worktree) |
| **Registry / active-workflows path** (2b) | auto-derive: `git rev-parse --git-common-dir` → slug → `~/.agent/workflows/<slug>/active_workflows.md` | manual — Main Repo Path = `<repo>/main`, Active-workflows Path = `~/.agent/workflows/<slug>/active_workflows.md` (slug from `autoMemoryDirectory` key). See `~/.agent/reference/bare-worktree/claude-state.md` → "Workflow registry & project-memory path". |

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
| **Any active/paused** | Read `~/.agent/reference/dev-workflow-isolation.md`, then `{{ .n.worktree }}` — requires isolation. |

> **Architecture-specific:** create the workspace per the **New-branch workspace** row of the dispatch table above. Under `ARCH=bare-worktree` the "None active → `checkout -b` in main" row does **not** apply — always create via `{{ .n.worktree }}`, Type=`worktree`.

The `active_workflows.md` row format:

| Change | Branch | Path | Type | Current Step | Status | Last Updated |

- **Path**: actual working directory (main repo or worktree path)
- **Type**: `main` or `worktree`
- **Current Step**: a tool-neutral semantic label (e.g. `apply-change done`, `review`) — this file is shared across tools, so never write a tool-specific skill token (such as a `$`-sigil'd `$openspec-…`); the resuming tool re-derives the token from its own name-map.
- **Status**: `active` or `paused`

Update Current Step + Last Updated after each skill completes. Set Status to `paused` when switching workflows. Remove the row after `{{ .n.finishBranch }}`.

## Step 3: Run the Core Flow

OpenSpec uses skill-based delivery — invoke by skill name (e.g. `{{ .n.sk }}openspec-new-change`),
NOT slash commands (`/opsx:*`). Skills are agent- and subagent-invocable and portable to
Codex; slash commands are user-typed UI only and unavailable to dispatched subagents.

### Small workflow

```
{{ .n.ensureScript }}
→ {{ .n.sk }}openspec-new-change → {{ .n.sk }}openspec-continue-change (loop until artifacts ready)
→ {{ .n.sk }}openspec-apply-change → openspec validate
→ [{{ .n.sk }}openspec-sync-specs — ask if implementation drifted from specs; promote design.md evergreen-candidates → context/] → {{ .n.sk }}openspec-archive-change
→ {{ .n.gitCommit }} → {{ .n.reviewQuick }}
→ Fixes needed? → Confirm scope, start a new change round (same branch/worktree, from {{ .n.sk }}openspec-new-change)
→ No fixes → {{ .n.finishBranch }} → [{{ .n.gitCleanGone }}]
```

### Large workflow

```
{{ .n.ensureScript }}
→ {{ .n.grill }}   (one question at a time; stop-gate = user confirms consensus;
   conclusions flow straight into the openspec artifacts, no separate design doc)
→ {{ .n.sk }}openspec-new-change → {{ .n.sk }}openspec-continue-change   (proposal + design.md + tasks.md into openspec/)
→ {{ .n.sk }}openspec-apply-change   (tasks with a testable seam agreed in design → {{ .n.tdd }})
→ {{ .n.verifyDone }} (run tests / verify commands — hard evidence)
→ {{ .n.sk }}openspec-verify-change (three-dimension spec/code coherence report)
→ openspec validate → {{ .n.sk }}openspec-sync-specs (promote design.md evergreen-candidates → context/) → {{ .n.sk }}openspec-archive-change
→ {{ .n.gitCommit }} → {{ .n.reviewFull }}
→ Fixes needed? → Confirm scope, start a new change round
→ No fixes → {{ .n.finishBranch }} → [{{ .n.gitCleanGone }}]
```

### `context/` evergreen promotion (at sync/archive)

`context/` is the evergreen, human-readable project-context bundle
consulted during requirement analysis (grill reads it; it is NOT auto-loaded
like CLAUDE.md). It is written only here, at `openspec-sync-specs`/archive —
never during grill, so every promoted line has shipped-implementation backing.

At sync/archive, scan `design.md` for `<!-- evergreen-candidate -->` markers.
For each, check it against what was actually implemented, then apply the
elevation gate: only **reusable, cross-change** principles and new domain
terms/glossary get promoted into `context/`, each into the concept file whose
kind it matches. One-off decisions stay in the archived `design.md`. Content
boundary: `specs/` = WHAT (behavior), `design.md` = one-off decisions,
`context/` = domain model + glossary + reusable principles.

### tasks.md slicing conventions

When writing tasks.md (either workflow):

- Each task is a tracer-bullet vertical slice: narrow but cutting a COMPLETE
  path through every layer — never sliced layer by layer.
- Each slice sized to fit one fresh context window.
- Declare dependencies between tasks (blocked by #N).
- Wide refactors are the exception: sequence expand–contract, migrate in
  batches sized by blast radius.

## Code Review Commands

{{ .n.reviewList }}
