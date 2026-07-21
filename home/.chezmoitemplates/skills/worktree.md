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

| ARCH | Command |
|------|---------|
| `normal` | From the main repo, off up-to-date main: `git worktree add ../<repo>-<branch> -b <branch>` |
| `bare-worktree` | From the container: `git --git-dir=.bare worktree add -b add-<name> add-<name> main` — one branch per worktree. See `~/.agent/reference/bare-worktree/operating.md`. |

Never `git checkout` another branch inside an existing worktree to
"reuse" it — one workflow, one workspace.

## Register

Add a row to `~/.agent/workflows/<repo-slug>/active_workflows.md`
(slug from `git rev-parse --git-common-dir`, `/`→`-`) with
Type=`worktree`, Path=the worktree directory. Keep Current Step
tool-neutral (no sigil'd skill tokens).
