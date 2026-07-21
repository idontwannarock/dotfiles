# Finish Branch

Complete a development branch: verify, integrate, dispose. Both repo
architectures are handled natively — no external overrides.

## 1. Verify before anything

Run the project's verification (tests / build / lint) and confirm
output. Do not offer integration options on a red branch.

## 2. Detect architecture

```bash
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
case "$(basename "$GIT_COMMON")" in
  .bare) ARCH=bare-worktree ;;
  *)     ARCH=normal ;;
esac
```

## 3. Ask how to integrate

Present once: **Merge locally** / **Push + PR** / **Keep branch as is**
/ **Discard**. Then execute per `ARCH`:

### ARCH=normal

- Merge locally: rebase on main first (pause on conflict), then
  `git checkout main && git merge <branch>`; delete the branch after.
- Push + PR: push branch, open PR (`gh pr create`), leave branch until
  merge; suggest cleanup later.
- If the work happened in a linked worktree: after merging, remove it
  with `git worktree remove <path>` before deleting the branch.

### ARCH=bare-worktree

Never checkout the base branch inside the feature worktree. Merge from
the worktree already pinned to base (e.g. `main/`), then always dispose:

```bash
cd <repo>/<feature-wt> && git rebase main     # resolve, rerun tests
cd <repo>/main && git merge --ff-only <branch>
git --git-dir=<repo>/.bare worktree remove <feature-wt>
git --git-dir=<repo>/.bare branch -d <branch>
git --git-dir=<repo>/.bare worktree prune
```

- Alternative `git merge --no-ff` from `main/` when branch history is
  worth keeping as a unit.
- Rebase rewrites hashes — update anything that recorded old hashes.
- Run the dispose sequence from `main/` or the container, never from
  inside the worktree being removed (dangling cwd breaks git).
- Never `rm -rf` a worktree directory (leaves stale admin records).

## 4. Clean up tracking

Remove this workflow's row from
`~/.agent/workflows/<repo-slug>/active_workflows.md`. Disposal and
row removal are part of finishing, not optional afterwork.
