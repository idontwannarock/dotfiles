---
type: Reference
title: Local files store
description: "How gitignored local files (.env and friends) stay available across branches and worktrees, backed by a per-repo global store."
---

# Local files store reference

Reference for **local-files**: keeping gitignored local files (`.env`,
`.env.local`, `.env.*.local`) available across branches and worktrees of a
repo, backed by a per-repo global store. Tool-agnostic.

The problem: these files are gitignored, so they don't travel with a branch
switch or into a fresh `git worktree`. A new working directory has no `.env`,
and tools that look in cwd
(dotenv, docker-compose, the app itself) break. There is also no single
durable copy on the machine.

## Authority — global store is a backup, the in-folder copy is the source

git only fires hooks on **checkout** events; there is no "leaving a worktree"
or "file was edited" hook. So syncing in-folder edits back automatically and
reliably is impossible. The model:

- **Global store** = durable backup, and the seed for fresh worktrees.
- **In-folder copy** = the working source of truth while you're in that
  worktree.
- `restore` only fills a **missing** file (never overwrites the copy you're
  editing). `backup` is **explicit** — you run it to push the current copy
  back to the store.

## Store layout

```
${XDG_STATE_HOME:-~/.local/state}/localfiles/<repo-id>/
    _default/        # shared bucket (main/dev and most branches)
    <branch>/        # per-branch override bucket, created on demand
```

- `<repo-id>` = `slug(dirname(realpath(git-common-dir)))` — the canonical-root
  absolute path with `/`→`-` (same `<id>` as `claude-memory-seed`). Stable
  across every branch and worktree of a repo: the canonical root is the main
  checkout, never an individual linked-worktree dir. Using the full path (not
  the folder name) keeps unrelated repos with the same dir name from
  colliding.
- **Restore** picks the `<branch>/` bucket if it exists, else `_default/`.
- **Backup** writes `_default/` by default; `--branch` writes the current
  branch's bucket (opting that branch into its own override, which restore
  then prefers).

## Managed files

A fixed convention, at the repo top level:

```
.env   .env.local   .env.*.local
```

Large gitignored data dirs are intentionally **not** auto-copied (expensive,
usually regenerable). Extend the list later if a real need shows up.

## The `localfiles` helper

```
localfiles restore            # store -> cwd repo, fills missing files only
localfiles backup [--branch]  # cwd repo -> store (_default, or branch bucket)
localfiles where              # print this repo's store path (debug)
```

`restore` runs automatically on checkout via the global post-checkout
dispatcher (see `setup.md`). `backup` is something you run by hand after
editing a `.env` you want preserved or shared to other worktrees.

## Agent read-fallback rule

`restore` normally makes the file appear at its expected in-folder path, so
the fallback only matters when restore hasn't run yet or the file lives only
in the store. When **an agent** needs to read a managed file (`.env` etc.)
and cannot find it in cwd:

> Look in `${XDG_STATE_HOME:-~/.local/state}/localfiles/<repo-id>/<branch>/`
> then `_default/`. If found, read it there (the in-folder copy is the
> source, so just read — don't silently copy it back into the folder). Only
> if it's absent from the store too should you treat it as genuinely missing
> and flag it.

## See also

- `setup.md` — one-time install (global `core.hooksPath` dispatcher + helper,
  all via chezmoi) and the per-repo `core.hooksPath` override to watch for.
