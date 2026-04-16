---
name: git-sync
description: Fetch and rebase current branch on main
---

## Context

First, gather context by running these commands:

- `git branch --show-current` — current branch
- `git status --short` — uncommitted changes
- `git remote -v | head -2` — remote URL

## Task

Sync the current branch with the main branch from remote.

1. If there are uncommitted changes, stash them first with `git stash`
2. Run `git fetch origin`
3. Rebase on `origin/main`: `git rebase origin/main`
4. If stashed in step 1, run `git stash pop`
5. If rebase conflicts occur, stop and report to the user — do NOT force resolve

Show a brief summary of what happened (new commits pulled, conflicts if any).
