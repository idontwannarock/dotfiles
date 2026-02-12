---
allowed-tools: Bash(git push:*), Bash(git status:*), Bash(git branch:*), Bash(git log:*)
description: Push current branch to remote
---

## Context

- Branch: !`git branch --show-current`
- Tracking: !`git status -sb`
- Unpushed commits: !`git log @{u}..HEAD --oneline 2>/dev/null || echo "No upstream set"`

## Task

Push the current branch to the remote.

- If the branch has no upstream, use `git push -u origin <branch>`
- If the branch already tracks a remote, use `git push`
- NEVER use `--force` or `--force-with-lease` unless the user explicitly asked for it
- Do not do anything else beyond the push
