---
type: Playbook
title: Bare + worktree — detecting & operating
description: "Daily-use rules for a bare+worktree repo: how to detect the layout, branch/worktree/stash handling, and finishing a branch back into the base."
---

# Bare + worktree — detecting & operating

Tool-agnostic. Daily-use rules for a repo organized as a bare git repo plus
per-branch worktrees. For creating the layout see `setup.md`; for Claude
Code's state handling see `claude-state.md`.

## How to detect this layout

You are in a bare+worktree layout when cwd is a git worktree whose **parent
directory contains a `.bare/` folder** alongside sibling worktree directories:

```
<repo>/
├── .bare/                  # the bare git repo (no working tree)
├── main/                   # worktree pinned to main
├── add-<feature-1>/        # worktree pinned to add-<feature-1>
└── add-<feature-2>/        # ...
```

Cross-check: `git rev-parse --git-common-dir` resolves to `.../.bare`, and
`git rev-parse --is-inside-work-tree` is true.

## Operating rules

- **One branch per worktree.** Never `git switch` / `git checkout <branch>`
  inside a worktree — that breaks the mental model and can collide with
  another worktree already on that branch. To work on a different branch,
  create another worktree.
- **Create a new long-lived branch** from the parent container:
  ```bash
  cd <repo>
  git --git-dir=.bare worktree add -b add-<name> add-<name> main
  cd add-<name>
  ```
- **Remove a worktree** with git, never plain `rm -rf` (leaves stale admin
  records):
  ```bash
  git --git-dir=.bare worktree remove add-<name>
  # branch -d must run from a worktree, NOT with --git-dir=.bare: the bare
  # repo's HEAD is often a dangling symref, and -d needs HEAD to run its
  # "is it merged" check.
  (cd main && git branch -d add-<name>)        # if merged
  ```
- **`.bare/HEAD` goes dangling on its own.** Nothing maintains it in this
  layout: it stays pinned to whatever branch it was left on, so the day that
  branch is deleted it becomes a symref to nothing and every `--git-dir=.bare`
  command needing HEAD fails with `Couldn't look up commit object for HEAD`.
  Each successful finish raises the odds of the next one breaking. Repair:
  ```bash
  git --git-dir=.bare symbolic-ref HEAD refs/heads/main
  ```
  Safe — under worktrees the bare HEAD is only a default-branch pointer.
- **Never open or operate at the parent container level.** It holds only
  `.bare/` — no source, no agent instructions, no context. Always be inside a
  worktree.
- **The whole tree is not relocatable.** Worktree admin files store absolute
  paths; if the container is renamed/moved, run
  `git --git-dir=.bare worktree repair`.
- `git stash` is repo-global — a stash made in one worktree is visible in all.
  Prefer commits over stash to avoid cross-worktree confusion.

## Finishing / merging a branch back

**Commands live in one place: the `finish-branch` skill's bare arm.** This
section keeps only the why — the layout invariants any finish must respect:

- A generic in-place "Merge Locally" (`git checkout <base> && git merge`)
  violates the one-branch-per-worktree rule and leaves the merged worktree
  behind. The merge happens in the worktree already pinned to the base
  branch (e.g. `main/`); on the local-merge path, finishing = merge **and**
  dispose, as one unit (Keep / open-PR paths deliberately defer disposal —
  see the `finish-branch` skill).
- Rebase rewrites commit hashes — anything that recorded old hashes
  (auto-memory `active_workflows`, design notes, the registry) must be
  updated afterwards.
- Never `rm -rf` a worktree directory (stale admin records), and never run
  the removal from inside the worktree being removed (dangling cwd breaks
  git). Work from `main/` or the container.
- Removing the workflow's `active_workflows.md` row is part of finishing,
  not a manual afterthought.

### Next piece of work → a fresh worktree

New feature, new requirement, or follow-up changes to the same feature: always
create a **new** worktree off `main` (via the `worktree` skill). Don't recycle
a disposed worktree's directory and don't edit directly in `main/`.

Sibling worktrees on other branches are untouched by all of this — they keep
their own branches and take no part in the merge.
