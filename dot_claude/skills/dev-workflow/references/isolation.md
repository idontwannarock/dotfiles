# Worktree Isolation

Read this when `active_workflows.md` has any active or paused rows.

## Why

A single git working directory can only have one branch checked out at a time. If another workflow is in progress (even paused), sharing the main repo risks conflicts when either session tries to merge, rebase, or switch branches. Worktree isolation eliminates this entire class of problems.

## Flow

1. Show the active workflows to the user. Ask: resume an existing one, or start a new one?
2. If starting new: invoke `superpowers:using-git-worktrees` to create an isolated worktree.
3. Register the new row in `active_workflows.md` with Type=`worktree`, Path=the worktree directory.

## Session start re-entry

Any new session receiving a task should re-read `active_workflows.md` first:
- Clean up stale entries (missing worktree paths, deleted branches)
- If any remain active → show them, ask resume or start new
- If none → proceed with Step 1 of the main flow
