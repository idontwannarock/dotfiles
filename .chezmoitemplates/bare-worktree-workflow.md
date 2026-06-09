# Bare + worktree repo workflow

Reference for repos organized as a bare git repo plus per-branch worktrees.
Loaded on demand (progressive disclosure) — the pointer lives in your
top-level agent instructions (CLAUDE.md / AGENTS.md).

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

## Claude state across worktrees

- **Auto-memory:** shared via `autoMemoryDirectory` in each worktree's
  `.claude/settings.local.json`. This explicit override is deliberate —
  native worktree memory resolution has changed between releases, so don't
  rely on it. A repo `post-checkout` hook seeds this file on new worktrees.
- **Transcripts / `--resume`:** recent Claude Code resumes sessions across
  worktrees of the same repo (switches cwd back). The bare layout (no main
  checkout) is an edge case — verify once per machine.
- **`.env` is the one thing a new worktree can't auto-figure-out** (secrets,
  gitignored, no discoverable source). Everything else — `uv sync`, codegraph
  indexing — can be done on the fly. Proactively flag a missing `.env`.

## Settings to set per repo (not globally)

Put these in the repo's `.claude/settings.local.json` so they scope to this
repo only and don't change behavior in non-bare repos:

```jsonc
{
  "autoMemoryDirectory": "~/.claude/memory/<repo-name>",
  "worktree": { "baseRef": "head" }
}
```

`worktree.baseRef: "head"` makes Claude's own isolation worktrees
(`--worktree`, `EnterWorktree`, Agent `isolation:"worktree"`) branch from
local HEAD instead of the default `origin/<default>` — important when you
routinely have unpushed commits.

## Workflow registry & project-memory path

The `dev-workflow` skill keeps a per-machine `~/.claude/workflow-registry.md`
mapping each repo to a **Main Repo Path** and **Project Memory Path**. Its
auto-derivation (`git rev-parse --git-common-dir` plus a cwd-slug project
path) assumes a normal checkout and is **wrong for a bare+worktree repo** —
`--git-common-dir` yields `.bare`, and the derived
`~/.claude/projects/<slug>/memory` path does not exist. Set the row by hand:

- **Project Memory Path** = the `autoMemoryDirectory` from this repo's
  `.claude/settings.local.json` (`~/.claude/memory/<repo-name>`). Migration
  consolidates both auto-memory (`MEMORY.md` + fact files) and workflow
  tracking (`active_workflows.md`) there. Don't use the cwd-slug
  `projects/<slug>/memory` path — it isn't created under this layout.
- **Main Repo Path** = the `main/` worktree (`<repo>/main`), never the parent
  container (which holds only `.bare/` and must never be operated at).

`active_workflows.md` therefore lives in `~/.claude/memory/<repo-name>/`
alongside the auto-memory facts. It's workflow state, not a remembered fact,
so it is **not** indexed in `MEMORY.md`.

## Not the same as `--bare`

The `--bare` CLI flag is a headless `-p` minimal-execution mode (skips hooks,
LSP, plugin sync; disables auto-memory). It has nothing to do with a bare git
repo. Claude has no special bare-repo mode — it simply runs inside whichever
worktree is its cwd.

## Bootstrapping on a new machine

```bash
mkdir <repo> && cd <repo>
git clone --bare <url> .bare
git --git-dir=.bare config core.hooksPath .githooks
git --git-dir=.bare worktree add main main      # fires post-checkout hook
```
