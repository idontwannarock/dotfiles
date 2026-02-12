---
allowed-tools: Bash(git reset:*), Bash(git log:*), Bash(git status:*)
description: Undo the last commit (soft reset, keeps changes staged)
---

## Context

- Last commit: !`git log -1 --format="%H %s"`
- Pushed status: !`git log @{u}..HEAD --oneline 2>/dev/null || echo "No upstream"`

## Task

Undo the last commit using soft reset, keeping all changes staged.

1. Check if the last commit has been pushed to remote (if `git log @{u}..HEAD --oneline` is empty, it's already pushed)
2. If already pushed: STOP and warn the user that undoing a pushed commit requires force-push. Do NOT proceed.
3. If not pushed: run `git reset --soft HEAD~1`
4. Show the result with `git status`
