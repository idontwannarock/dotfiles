# Worktree

Create an isolated workspace for a workflow. Read
`~/.agent/reference/dev-workflow-isolation.md` first when deciding
whether isolation is required (any active/paused row in
`active_workflows.md` → yes).

## Detect architecture (once)

```bash
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
case "$(basename "$GIT_COMMON")" in
  .bare) ARCH=bare-worktree ;;
  *)     ARCH=normal ;;
esac
```

## Create the workspace

Ensure `main` is up to date first (fetch/pull in the main checkout).

| ARCH | Command |
|------|---------|
| `normal` | From the main repo: `git worktree add ../<repo>-<branch> -b <branch> main` — the explicit `main` start-point matters; without it the worktree branches from current HEAD (likely another workflow's feature branch). |
| `bare-worktree` | From the container: `git --git-dir=.bare worktree add -b <branch> <branch> main` — directory named after the branch, one branch per worktree. See `~/.agent/reference/bare-worktree/operating.md`. |

- If the target directory or branch name already exists, stop and pick
  another name (or resume the existing workflow) — do not force.
- Never `git checkout` another branch inside an existing worktree to
  "reuse" it — one workflow, one workspace.
- The `--git-dir=.bare` form only works from the container directory;
  run it there.

## Register

Resolve the active-workflows path per `ARCH` (same dispatch as
dev-workflow Step 2b):

- `normal`: auto-derive — `git rev-parse --git-common-dir` → slug
  (`/`→`-`) → `~/.agent/workflows/<slug>/active_workflows.md`.
- `bare-worktree`: auto-derivation is WRONG here (the slug would end in
  `-.bare`) — look up the repo's row in `~/.agent/workflow-registry.md`
  (slug from the `autoMemoryDirectory` key). See
  `~/.agent/reference/bare-worktree/claude-state.md`.

`mkdir -p` the directory if this is the repo's first workflow, then add
a row (`Change | Branch | Path | Type | Current Step | Status | Last
Updated`) with Type=`worktree`, Path=the worktree directory. Keep
Current Step tool-neutral (no tool-specific skill tokens). Register
only after the worktree was actually created — a failed `worktree add`
must not leave an orphan row.
