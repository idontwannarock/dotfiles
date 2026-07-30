---
type: Reference
title: Bare + worktree — why only this one architecture
description: "Why this reference documents bare+worktree and nothing else: the .git vs .bare dispatch rule, the layout x discipline matrix, and what to do when the unfilled cell appears."
---

# Bare + worktree — why only this one architecture

This reference documents the **deviation** of bare+worktree from the default
repo layout; it is not a catalogue of every git architecture. The dev-workflow
dispatch table keys on `basename "$(git rev-parse --git-common-dir)"`:

- **`.git` → a primary checkout exists.** Covers both classic normal repos
  **and** normal repos using `git worktree add` linked worktrees. dev-workflow
  treats them identically and the `finish-branch` skill's normal arm is correct
  for them (in-place checkout of the base branch works because a primary
  worktree exists). No reference needed — that's the assumed default everything
  is written against.
- **`.bare` → no primary checkout.** `<common-dir>/..` is the container, not a
  worktree, so in-place merge/cleanup breaks. The `finish-branch` skill's bare
  arm handles this natively; this reference documents the layout's background
  and manual operations.

The real space is 2×2 — *layout* (primary checkout vs bare) × *discipline*
(work in-place vs every branch is a worktree). bare+worktree bundles "no
primary" with "worktree discipline". The one unfilled cell — a **normal repo
run with worktree discipline** (primary parked on `main`, all work in linked
worktrees) — has no instance today; it would want these operating rules but
normal's plumbing. If it ever appears, promote `discipline` to its own
dimension and rename this dir to `git-layouts/<arch>/`.
