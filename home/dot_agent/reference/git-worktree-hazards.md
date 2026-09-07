---
type: Reference
title: Git worktree hazards
description: "The four ways a linked worktree goes wrong without erroring — a missing start-point, staying in the main checkout, disposing from the wrong directory, and using git branch -d as a merged-gate."
---

# Git worktree hazards

`git worktree` is ordinary git, and any agent can drive it. What follows is
not the command list — it is the four places where the wrong move **does not
error**. Each one produces a plausible-looking result, which is why they need
writing down rather than discovering.

This file is workflow-agnostic. It says nothing about when to isolate work or
where to record it; that belongs to whatever development workflow the repo
runs.

## 1. `worktree add` without an explicit start-point

```bash
git worktree add ../<repo>-<branch> -b <branch> main
```

The trailing `main` is load-bearing. Without it the new branch starts from the
**current HEAD**, which in a repo that already has work in flight is another
feature branch. The worktree is created, the branch exists, and the base is
wrong. Nothing reports it.

Run it from the main checkout, on an up-to-date `main` (fetch/pull first).

If the target directory or the branch name already exists, stop and pick
another name, or resume the existing work. Do not force. Never `git checkout`
a different branch inside an existing worktree to "reuse" it — one line of
work, one workspace.

## 2. `worktree add` does not move you

The command creates the directory and leaves your shell where it was. Every
later command for this work belongs in the new directory, so `cd` there and
confirm both facts:

```bash
cd ../<repo>-<branch> && git rev-parse --show-toplevel && git branch --show-current
```

Both must name the new workspace. Editing the main checkout while believing
you are in the worktree puts the work on the wrong branch, and **nothing
complains** — this confirmation is the only thing that catches it.

## 3. Disposal runs from the main checkout, never from inside the worktree

Establish the two directories once, before any integration step:

```bash
WORK=$(git rev-parse --show-toplevel)          # this line of work's workspace
BRANCH=$(git branch --show-current)
MAIN=$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')
[ "$WORK" = "$MAIN" ] && LINKED=no || LINKED=yes
```

The first row of `git worktree list` is always the one holding `.git` itself.
`LINKED=yes` constrains two things:

- **Anything touching the base branch runs in `$MAIN`.** `git checkout main`
  inside a linked worktree fails outright: `fatal: 'main' is already checked
  out at <main>`. Rebasing the feature branch is the one step that belongs in
  `$WORK`.
- **`git worktree remove` runs from `$MAIN`.** It does *not* refuse when your
  shell sits inside the directory it is deleting. It removes the tree, and
  every later command in that shell dies with `Unable to read current working
  directory`. `cd "$MAIN"` first. This is a hard ordering, not a preference.

Never `rm -rf` a worktree directory. `git worktree remove` also clears the
bookkeeping under `.git/worktrees/`; `git worktree prune` afterwards.

When `LINKED=no` there is no worktree to remove, and `$WORK` and `$MAIN` are
the same place.

## 4. `git branch -d` cannot answer "did it merge?"

`-d` tests whether the branch tip is an ancestor of the base. Squash and
rebase merges rewrite the commit, so it reports "not fully merged" for a
merged branch and a genuinely unmerged one alike — the guard stops
discriminating, and reaching for `-D` to silence it discards the question
instead of answering it.

Use the test that still holds:

```bash
paths=$(git diff --name-only "$(git merge-base main "$BRANCH")" "$BRANCH")
git diff main "$BRANCH" -- $paths        # MUST be empty
```

Empty means the branch's tree is entirely on the base and nothing is lost.
That holds for merge-commit, squash, rebase and cherry-pick alike.

**Scope the comparison to the paths the branch touched.** An unscoped
`git diff main <branch>` is ambiguous: non-empty can mean the branch's work
never landed, or merely that the base moved on unrelated files while the
branch was open — one dependency bump merging ahead of you is enough. Scoped,
only the first reading survives. Still non-empty means the base also moved on
*these* paths; stop and look.

After a plain fast-forward merge you did yourself, `git branch -d` is fine —
it is only a false gate for merges performed elsewhere.
