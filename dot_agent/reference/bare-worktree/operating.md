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
  git --git-dir=.bare branch -d add-<name>     # if merged
  ```
- **Never open or operate at the parent container level.** It holds only
  `.bare/` — no source, no agent instructions, no context. Always be inside a
  worktree.
- **The whole tree is not relocatable.** Worktree admin files store absolute
  paths; if the container is renamed/moved, run
  `git --git-dir=.bare worktree repair`.
- `git stash` is repo-global — a stash made in one worktree is visible in all.
  Prefer commits over stash to avoid cross-worktree confusion.

## Finishing / merging a branch back

This section **overrides** generic finishing skills (e.g. superpowers'
`finishing-a-development-branch`): their "Merge Locally" option does
`git checkout <base> && git merge <feature>` in place, which violates the
one-branch-per-worktree rule, and they leave the merged worktree behind.
Under this layout, finishing = merge **and** dispose, as one unit.

### 1. Merge from the base worktree, never checkout in place

Never `git checkout <base>` inside the feature worktree. The merge happens
in the worktree already pinned to the base branch (e.g. `main/`).

Preferred — linear history (rebase + fast-forward):

```bash
cd <repo>/add-<name>          # feature worktree
git rebase main               # resolve conflicts here, rerun tests
cd <repo>/main                # base worktree
git merge --ff-only add-<name>
```

Alternative — merge commit: skip the rebase and run
`git merge --no-ff add-<name>` from `main/`. Trade-off: no hash rewriting
(history notes stay valid) but a non-linear graph; pick it when the branch
history is worth preserving as a unit or a rebase would be painful.

**Rebase rewrites commit hashes.** Any place that recorded the old hashes —
auto-memory `active_workflows`, design notes, the workflow registry — must be
updated. Identify work by commit message or by the post-merge hash, not by
pre-rebase hashes.

### 2. Dispose of the worktree + branch — always

After the merge, **always** remove the feature worktree and branch. Leaving
merged worktrees around accumulates stale directories and ties up the branch.
Order matters: a branch can't be deleted while a worktree still holds it.

```bash
git --git-dir=<repo>/.bare worktree remove add-<name>
git --git-dir=<repo>/.bare branch -d add-<name>   # -d is safe after FF merge
git --git-dir=<repo>/.bare worktree prune
```

Never `rm -rf` the worktree directory (leaves stale admin records).

**Do not run the removal from inside the worktree being removed.** If the
shell's or agent's cwd is that worktree, removal leaves cwd dangling —
`getcwd` fails and subsequent git commands break. Run the whole
merge/dispose sequence from the base worktree (`main/`) or the container.
Ideally the agent driving the finish doesn't live in the worktree being
deleted; if the session did start there, move to `main/` (or a new
worktree) before removing.

If a workflow tracker is in use (e.g. dev-workflow's `active_workflows.md`),
remove the branch's row as part of this dispose step — it is part of
finishing, not a manual afterthought.

### 3. Next piece of work → a fresh worktree

New feature, new requirement, or follow-up changes to the same feature: always
create a **new** worktree (per the creation rule above:
`git --git-dir=.bare worktree add -b add-<name> add-<name> main`). Don't
recycle a disposed worktree's directory and don't edit directly in `main/`.

Sibling worktrees on other branches are untouched by all of this — they keep
their own branches and take no part in the merge.
