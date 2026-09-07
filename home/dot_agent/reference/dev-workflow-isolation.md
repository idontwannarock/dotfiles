---
type: Playbook
title: Worktree isolation
description: "When active_workflows.md has active or paused rows, isolate the new workflow in its own worktree instead of sharing the main repo."
---

# Worktree Isolation

Read this when `active_workflows.md` has any active or paused rows.

## Why

A single git working directory can only have one branch checked out at a time. If another workflow is in progress (even paused), sharing the main repo risks conflicts when either session tries to merge, rebase, or switch branches. Worktree isolation eliminates this entire class of problems.

## Flow

1. Show the active workflows to the user. Ask: resume an existing one, or start a new one?
2. If starting new: create the worktree per `~/.agent/reference/git-worktree-hazards.md`
   — from the main checkout, off an up-to-date `main`, with the start-point
   spelled out, then `cd` into it and confirm you moved. Read that file; the
   two steps it guards both fail without erroring.
3. Register the new row in `active_workflows.md` with Type=`worktree`, Path=the worktree directory.
   Register only after the worktree was actually created — a failed
   `worktree add` must not leave an orphan row.

## Session start re-entry

Any new session receiving a task should re-read `active_workflows.md` first:
- Clean up stale entries (missing worktree paths, deleted branches)
- If any remain active → show them, ask resume or start new
- If none → proceed with Step 1 of the main flow
