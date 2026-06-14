# Bare + worktree repo reference

Reference for repos organized as a bare git repo plus per-branch worktrees.
Loaded on demand (progressive disclosure) — the pointer lives in your
top-level agent instructions (CLAUDE.md / AGENTS.md), which read this index
when cwd looks like a bare+worktree layout.

This reference is **tool-agnostic** unless a file says otherwise.

## Scope — why only this one architecture

This reference documents the **deviation** of bare+worktree from the default
repo layout; it is not a catalogue of every git architecture. The dev-workflow
dispatch table keys on `basename "$(git rev-parse --git-common-dir)"`:

- **`.git` → a primary checkout exists.** Covers both classic normal repos
  **and** normal repos using `git worktree add` linked worktrees. dev-workflow
  treats them identically and the stock `finishing-a-development-branch` skill
  is correct for them (its `MAIN_ROOT = <common-dir>/..` resolves to the primary
  worktree, so its in-place checkout works). No reference needed — that's the
  assumed default everything is written against.
- **`.bare` → no primary checkout.** `<common-dir>/..` is the container, not a
  worktree, so the skill's merge/cleanup breaks. This is the deviation this
  reference exists for.

The real space is 2×2 — *layout* (primary checkout vs bare) × *discipline*
(work in-place vs every branch is a worktree). bare+worktree bundles "no
primary" with "worktree discipline". The one unfilled cell — a **normal repo
run with worktree discipline** (primary parked on `main`, all work in linked
worktrees) — has no instance today; it would want these operating rules but
normal's plumbing. If it ever appears, promote `discipline` to its own
dimension and rename this dir to `git-layouts/<arch>/`.

## When to read which file

| File | Read it when | Audience |
|------|--------------|----------|
| `operating.md` | You're working inside one of these worktrees day to day — confirm the layout, branch/worktree/stash rules, and how to finish/merge a branch back (incl. worktree disposal). | any tool |
| `setup.md` | You're creating the layout — fresh clone on a new machine, or converting an existing flat repo. | any tool |
| `claude-state.md` | You need Claude Code's state to behave under this layout — auto-memory, transcripts, per-repo settings, workflow registry, the `--bare` flag. | **Claude-specific** — other tools can skip; add a sibling `<tool>-state.md` if needed |

Start with `operating.md` to confirm you're actually in a bare+worktree layout.
