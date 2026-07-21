# Finish Branch

Complete a development branch: verify, integrate, dispose. Both repo
architectures are handled natively — no external overrides.

## Ground rules (apply to every option below)

- **Stop on first failure.** Each command is a separate gated step; if
  any fails (rebase conflict, `--ff-only` refused, anything), stop,
  report the state, and wait — do NOT run the remaining steps.
- **Dispose only after the merge is confirmed.** Worktree/branch
  disposal and `active_workflows.md` row removal happen only once the
  merge commit is verifiably on the base branch (or the user confirmed
  Discard). A half-finished sequence keeps the row.

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

## 3. Ask how to integrate, then execute per option × ARCH

Present once: **Merge locally** / **Push + PR** / **Keep branch as is**
/ **Discard**.

### Merge locally

- `normal`: rebase on up-to-date main (pause on conflict) →
  `git checkout main && git merge <branch>` → after the merge is
  confirmed, delete the branch; if the work was in a linked worktree,
  `git worktree remove <path>` first.
- `bare-worktree`: never checkout the base inside the feature worktree.
  ```bash
  cd <repo>/<branch> && git rebase main     # conflict → stop, resolve, rerun tests
  cd <repo>/main && git merge --ff-only <branch>   # refused → stop, report (main moved?)
  # ── only continue once the merge above succeeded ──
  git --git-dir=<repo>/.bare worktree remove <branch>
  git --git-dir=<repo>/.bare branch -d <branch>    # -d is safe after FF merge
  git --git-dir=<repo>/.bare worktree prune
  ```
  Alternative `git merge --no-ff <branch>` from `main/` when the branch
  history is worth keeping as a unit. Rebase rewrites hashes — update
  anything that recorded old ones. Run disposal from `main/` or the
  container, never from inside the worktree being removed. Never
  `rm -rf` a worktree directory.
- Then remove the workflow's row from `active_workflows.md` — resolve its
  path per ARCH first (normal: auto-derived slug; bare-worktree: registry
  lookup via `autoMemoryDirectory` key, auto-derivation is wrong there —
  same dispatch as the `worktree` skill's Register step).

### Push + PR

Both ARCHes: push the branch, `gh pr create`. The branch — and under
bare-worktree the worktree — stays until the PR merges (review fixes
need the workspace). Keep the `active_workflows.md` row, update Current
Step (e.g. `pr-open`); dispose + remove the row only after the PR
merges.

### Keep branch as is

Leave branch, worktree, and the `active_workflows.md` row untouched
(update Status/Current Step if the workflow is pausing). No disposal.

### Discard

Destroys unmerged commits — **confirm with the user before deleting**,
then:
- `normal`: `git checkout main`, remove the linked worktree if any,
  `git branch -D <branch>`.
- `bare-worktree`: `git --git-dir=<repo>/.bare worktree remove
  <branch>` (add `--force` only if the tree is dirty and the user
  confirmed), `git --git-dir=<repo>/.bare branch -D <branch>`,
  `worktree prune`.
- Then remove the `active_workflows.md` row.
