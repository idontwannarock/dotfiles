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
