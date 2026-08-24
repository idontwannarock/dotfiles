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
| **Registry / active-workflows path** (2b) | auto-derive the canonical repo slug, then `~/.agent/workflows/<slug>/active_workflows.md` | same slug derivation (the anchor's `dirname` strips `.bare`, leaving the container) — but **Main Repo Path** = `<repo>/main`, not the container, so that half is manual. See `~/.agent/reference/bare-worktree/claude-state.md` → "Workflow registry & active-workflows path". |

### 2a. Sync main

Run `{{ .n.gitSync }}` unless already on a worktree.

### 2b. Resolve workflow registry

Look up `~/.agent/workflow-registry.md` for this repo's main repo path, active-workflows path, and `Doc Target` (the team-doc step below reads it; carry it forward, do not act on it here). If no entry: derive the repo's canonical slug per `~/.agent/reference/repo-identity.md` — read it rather than reconstructing the rule from memory; the two plausible shortcuts both name a different directory and fail silently — set active-workflows path to `~/.agent/workflows/<repo-slug>/active_workflows.md`, add a row with `Doc Target` left blank — **do not ask the user about it now**. Registry is per-machine, not synced, and its rows are append-only: never drop a row because a workflow ended.

> **Architecture-specific:** follow the **Registry / active-workflows path** row of the dispatch table above for your `ARCH`. Under `bare-worktree` the slug still derives correctly; it is **Main Repo Path** that must be set by hand per `claude-state.md`.

### 2c. Check active workflows

Read `~/.agent/workflows/<repo-slug>/active_workflows.md` (same canonical slug as 2b). Clean stale entries (missing worktree paths, deleted branches).

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
→ [{{ .n.sk }}openspec-sync-specs — ask if implementation drifted from specs; promote design.md evergreen-candidates → the repo-root `context/`] → {{ .n.sk }}openspec-archive-change
→ {{ .n.gitCommit }} → {{ .n.reviewQuick }}
→ Fixes needed? → Confirm scope, start a new change round (same branch/worktree, from {{ .n.sk }}openspec-new-change)
→ No fixes → [team-doc step] → {{ .n.finishBranch }} → [{{ .n.gitCleanGone }}]
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
→ openspec validate → {{ .n.sk }}openspec-sync-specs (promote design.md evergreen-candidates → the repo-root `context/`) → {{ .n.sk }}openspec-archive-change
→ {{ .n.gitCommit }} → {{ .n.reviewFull }} → {{ .n.reviewCrossModel }}
→ Fixes needed? → Confirm scope, start a new change round
→ No fixes → [team-doc step] → {{ .n.finishBranch }} → [{{ .n.gitCleanGone }}]
```

`{{ .n.reviewCrossModel }}` hands the review's filtered findings to an agent of a
different kind and has both sides refute each other once, because the six lenses
in `{{ .n.reviewFull }}` share their priors and their blind spots. It is
read-only, degrades rather than blocking when no counterpart is available, and
grades on the exchange: upheld by both sides → Critical, refuted → dropped with
the reason, raised by one side only → a **Split** for the user to settle. Never
resolve a split yourself.

Small workflow does not run it. A change of a few dozen lines rarely produces a
disagreement worth the round trip, and a gate that keeps returning nothing is a
gate people learn to skip.

### Team-doc step (both workflows)

**`Doc Target` is `none` → skip this whole section.** Do not ask, do not
propose, go straight to `{{ .n.finishBranch }}`. That column came from step 2b.

**{{ .n.teamDocGap }}** And if `Doc Target` names a space `{{ .n.teamDoc }}`
does not support yet, the write is off the table before it is proposed: say so,
say it needs that skill's coordinates generalized first, and never reach for the
team space's coordinates on another space.

Otherwise, just before `{{ .n.finishBranch }}`, ask one question:

> Could someone outside this repo answer what this change produced — how to
> operate it, or why it was designed this way — anywhere other than by reading
> the diff? **No → it is worth writing up.**

The signal is bound to **who the readers are**, not to diff size, so both
workflows run it: a three-line change can produce the switchover procedure
another team has to follow. The content boundary below (under *repo-root `context/`
evergreen promotion*) lists three carriers whose readers all sit inside the
repo; this step covers the fourth reader, the one outside.

Worth writing → state the reason and a proposed title and let the user decide,
then hand it to `{{ .n.teamDoc }}`, which owns the ARCH/RUNBOOK/KB choice
through its own doc-taxonomy rules — do not re-derive that here. Not worth
writing → **say nothing at all**. A routine "nothing to document this time" is
what turns a gate into noise people learn to read past.

The per-repo half is the `Doc Target` column: blank, a hub page URL/ID, or
`none`. Blank means nobody has been asked yet; `none` means this repo
deliberately has no team space. Read it at step 2b — that step already does —
but **ask only once the per-change question comes out yes**, then write the
answer back. Asking up front makes the user rule on an abstract question before
they know what the change produced.

Every outcome here, degraded or skipped or declined, still ends at
`{{ .n.finishBranch }}`: this step reports, it never blocks.

### Repo-root `context/` evergreen promotion (at sync/archive)

`context/` sits at the **repo root**, never `openspec/context/`. It is the
evergreen, human-readable project-context bundle consulted during requirement
analysis (grill reads it; it is NOT auto-loaded like CLAUDE.md). It is written
only here, at `openspec-sync-specs`/archive — never during grill, so every
promoted line has shipped-implementation backing.

At sync/archive, scan `design.md` for `<!-- evergreen-candidate -->` markers.
For each, check it against what was actually implemented, then apply the
elevation gate: only **reusable, cross-change** principles and new domain
terms/glossary get promoted into `context/`, each into the concept file whose
kind it matches. One-off decisions stay in the archived `design.md`. Content
boundary: `openspec/specs/` = WHAT (behavior), `design.md` = one-off decisions,
repo-root `context/` = domain model + glossary + reusable principles, `docs/` =
operating steps, troubleshooting, and rationale that explains only one case.

### tasks.md slicing conventions

When writing tasks.md (either workflow):

- Each task is a tracer-bullet vertical slice: narrow but cutting a COMPLETE
  path through every layer — never sliced layer by layer.
- Each slice sized to fit one fresh context window.
- Declare dependencies between tasks (blocked by #N).
- Wide refactors are the exception: sequence expand–contract, migrate in
  batches sized by blast radius.

## When this line is one of several (coordinated mode)

If a coordinator dispatched this line — several lines run in parallel and one
agent holds them together — the flow above is unchanged, but five obligations
are added. Full rules live in the `{{ .n.coordinate }}` skill; this is the
line-side contract.

**Address the coordinator by the name your dispatch message gave you, never by pane
id and never by a fixed string.** Report with `herdr agent prompt <that-name> "..."`.
Pane ids change on handover; the name does not. But the name is **fleet-scoped**
(`<fleet>-coordinator`), because herdr names live in one flat machine-wide namespace —
a hardcoded `coordinator` resolves to whichever fleet claimed it first, silently
delivering your report to another repo's coordinator. If the dispatch message carried no
address, that dispatch is broken: report it as fog rather than guessing a name.

**Verify the recipient before sending — two checks, not one.** The name must start with
your own fleet prefix, and `herdr agent list` gives that agent a `cwd` which must resolve to
the same repo as yours. The prefix half is not optional: a second fleet may run in this same
repo, and its cwd is identical to yours.

Compare the git common dir, not a path prefix — worktrees share no prefix with the main
checkout — and compute the recipient's from *its* directory:

```bash
mine=$(realpath "$(git rev-parse --path-format=absolute --git-common-dir)")
theirs=$(realpath "$(git -C "<their cwd>" rev-parse --path-format=absolute --git-common-dir)")
```

Without `-C` you compute your own common dir and compare it against itself, and the guard
checks nothing. `--path-format` also affects only the options that follow it: placed after
`--git-common-dir` it silently does nothing and still exits 0, leaving a cwd-relative `.git`.
Mismatch means do not send. This is the only check that catches a stale or wrong address,
because both ends of a misdelivery look completely normal.

**Report cross-line facts immediately, not at the end.** Anything another line
could also touch: shared fixtures, a measurement both lines assert on, migration
version numbers, decision-number ranges, a port or test file in both blast radii.
Your local view is never the whole truth — a number you measured is true only for
the base you measured it on, and the coordinator is the only one merging those
into one answer. Waiting until merge means the wrong number already shipped.

**A ruling with a wrong premise should be pushed back on, not executed.** The
coordinator's question frame can itself be wrong, and answering only within the
options offered turns its error into a decision. If the frame is wrong, say the
frame is wrong. Likewise refuse instructions that would corrupt your own evidence
— e.g. running an experiment inside your own session that interrupts the turn
you are reporting on.

**If your channel for asking the user directly has been closed, escalate — do
not substitute a default.** A dispatched line often runs without the ability to
put a question to the user in its own session, because the user talks to the
coordinator, not to each line. When you then hit a decision your own information
cannot settle — an exclusive shared resource like a migration version, a number
range, a port — report it to the coordinator by name and **stop at that step**.

Naming the risk after choosing anyway does not discharge this. "I'll use the
next number, though the coordinator should really be allocating these" leaves a
file on disk with a number in it; the caveat changes nothing that happens next.
A statement of uncertainty only counts while it can still alter the outcome.

Closing that channel does not close your right to disagree. If the coordinator's
question frame is itself wrong, say so in your report — that path runs through
text, and text still reaches it.

At `{{ .n.finishBranch }}`, report **four independent signals** and expect the
coordinator to verify them itself: MR/PR merged, handoff archived, worktree/branch
disposed, `active_workflows.md` row removed (anchored on the change name).
Verify "merged" with a scoped diff, not `git branch -d` — under squash merges
that command answers the same for "merged" and "never merged".

## Code Review Commands

{{ .n.reviewList }}
