---
allowed-tools: Bash(git fetch:*), Bash(git rebase:*), Bash(git stash:*), Bash(git status:*), Bash(git branch:*), Bash(git log:*)
description: Fetch and rebase current branch on main
---

## Context

- Branch: !`git branch --show-current`
- Status: !`git status --short`
- Remote: !`git remote -v | head -2`

## Task

Sync the current branch with the main branch from remote.

1. If there are uncommitted changes, stash them first with `git stash`
2. Run `git fetch origin`
3. Rebase on `origin/main`: `git rebase origin/main`
4. If stashed in step 1, run `git stash pop`
5. If rebase conflicts occur, stop and report to the user — do NOT force resolve

Show a brief summary of what happened (new commits pulled, conflicts if any).
