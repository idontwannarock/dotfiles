---
name: git-push
description: Push current branch to remote
---

## Context

First, gather context by running these commands:

- `git branch --show-current` — current branch
- `git status -sb` — tracking info
- `git log @{u}..HEAD --oneline 2>/dev/null || echo "No upstream set"` — unpushed commits

## Task

Push the current branch to the remote.

- If the branch has no upstream, use `git push -u origin <branch>`
- If the branch already tracks a remote, use `git push`
- NEVER use `--force` or `--force-with-lease` unless the user explicitly asked for it
- Do not do anything else beyond the push
