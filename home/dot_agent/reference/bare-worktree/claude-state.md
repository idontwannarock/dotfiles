---
type: Reference
title: Bare + worktree — Claude Code state
description: "Claude-specific: how auto-memory, transcripts, per-repo settings and the workflow registry behave under a bare+worktree layout."
---

# Bare + worktree — Claude Code state

**Claude-specific.** How Claude Code's state behaves under a bare+worktree
layout. Other AI tools can skip this file (add a sibling `<tool>-state.md` if
your tool needs equivalent handling). For the tool-agnostic git mechanics see
`operating.md` and `setup.md`.

## Claude state across worktrees

- **Auto-memory:** every git repo's auto-memory is consolidated at
  `~/.claude/memory/<id>`, where `<id>` is the repo's **canonical-root path**
  slugified (`/`→`-`) — the main checkout for a normal repo, the container for
  a bare+worktree layout. Anchoring on `dirname(git-common-dir)` makes `<id>`
  identical for all worktrees of a repo (so they share one memory home) and
  unique across repos (full path, no folder-name clash). Set via
  `autoMemoryDirectory` in the worktree's `.claude/settings.local.json`; this
  explicit override is deliberate — native worktree memory resolution has
  changed between releases. Seeding **and migration** are automatic and
  centralized: the `claude-memory-seed` helper (`~/.local/bin`) writes the key
  and, on first run, moves any existing memory (old basename dir, then Claude's
  default `projects/<id>/memory`) into the new home — transcripts stay put.
  Fired from two triggers: Claude's SessionStart hook (covers pre-existing
  repos, no git event needed) and the global `post-checkout` dispatcher (new
  worktrees at `worktree add`). It never overwrites a value pointing outside the
  managed roots (`~/.claude/memory`, `~/.claude/projects`), so it's safe to
  leave on. Only `autoMemoryDirectory` is auto-seeded; `worktree.baseRef` below
  stays a manual setting.
- **Non-git projects are covered too.** A plain directory (no repo) is anchored
  on `CLAUDE_PROJECT_DIR`, falling back to cwd, and gets the same
  `~/.claude/memory/<id>` treatment — only the SessionStart trigger reaches it,
  since there is no checkout event. Three locations are refused outright,
  whether or not they are repos: `$HOME` (the file would land in Claude's
  **user-level** `~/.claude/settings.local.json`, making `autoMemoryDirectory`
  global and collapsing every project's memory into one bucket), `/`, and
  anything under `/tmp` (a throwaway clone would leave a permanent
  `~/.claude/memory/` entry pointing at a path that vanishes on reboot).
- **Cross-tool note:** this is Claude-only. Codex and other agents use
  incompatible, non-relocatable memory stores — Codex keeps a global
  `~/.codex/memories/` (markdown + SQLite state) with no per-project
  memory-directory setting (only `CODEX_HOME` moves the whole home). So memory
  can't be shared into a common tool-neutral `~/.agent` location today; that's
  why this lives under Claude's own `~/.claude/memory/`.
- **Transcripts / `--resume`:** recent Claude Code resumes sessions across
  worktrees of the same repo (switches cwd back). The bare layout (no main
  checkout) is an edge case — verify once per machine.
- **`.env` and other gitignored local files** are filled into a fresh worktree
  by the local-files restore mechanism (global `post-checkout` dispatcher) when
  a copy exists in the global store — see `../local-files/store.md`. Everything
  else — `uv sync`, codegraph indexing — can be done on the fly. Only flag a
  missing `.env` when the global store has no copy either (run `localfiles
  backup` once in a worktree that has it to seed the store).

## Settings to set per repo (not globally)

`autoMemoryDirectory` is now **auto-seeded** by `claude-memory-seed` (above), so
you rarely set it by hand. `worktree.baseRef` is still manual — put it in the
repo's `.claude/settings.local.json`:

```jsonc
{
  "autoMemoryDirectory": "~/.claude/memory/<id>",   // auto-seeded; <id> = canonical-root path slug
  "worktree": { "baseRef": "head" }                 // manual
}
```

`worktree.baseRef: "head"` makes Claude's own isolation worktrees
(`--worktree`, `EnterWorktree`, Agent `isolation:"worktree"`) branch from
local HEAD instead of the default `origin/<default>` — important when you
routinely have unpushed commits.

## Workflow registry & active-workflows path

The `dev-workflow` skill keeps a per-machine `~/.agent/workflow-registry.md`
mapping each repo to a **Main Repo Path** and **Active-workflows Path**. Its
auto-derivation (`git rev-parse --git-common-dir` → slug →
`~/.agent/workflows/<slug>/active_workflows.md`) assumes a normal checkout
and is **wrong for a bare+worktree repo** — `--git-common-dir` yields `.bare`,
and the derived slug does not match the intended repo slug. Set the row by
hand:

- **Active-workflows Path** = `~/.agent/workflows/<slug>/active_workflows.md`,
  where `<slug>` is the same id used as the `autoMemoryDirectory` key (i.e.
  the canonical-root path slugified with `/`→`-`). `active_workflows.md` lives
  here separately from Claude's auto-memory (`~/.claude/memory/<id>`). It's
  workflow state, not a remembered fact, so it is **not** indexed in
  `MEMORY.md`.
- **Main Repo Path** = the `main/` worktree (`<repo>/main`), never the parent
  container (which holds only `.bare/` and must never be operated at).

## Migrating Claude state — memory vs transcripts go to DIFFERENT roots

When converting an existing flat repo (see `setup.md`), migrate Claude's
state too. This is the easy thing to get wrong:

- **Memory → `autoMemoryDirectory`** (`~/.claude/memory/<id>`) is handled
  **automatically** by `claude-memory-seed` on the next session/checkout (it
  moves `projects/<id>/memory` into `~/.claude/memory/<id>`). You only do it by
  hand if seeding is somehow disabled — and even then the source projects-slug
  memory is often **empty**, so "nothing to copy" ≠ "nothing to do": still
  scaffold `MEMORY.md` (+ fact files) at the new home.
- **Transcripts → new cwd-slug projects dir** (`~/.claude/projects/<new-slug>/`),
  where `<new-slug>` = the `main/` worktree path with `/`→`-`. Copy the `*.jsonl`
  so `--resume`/`--continue` work at the new location. Transcripts are **not**
  moved by the seeder — only `memory/` is.

Memory and transcripts therefore live under **separate roots by design**
(`~/.claude/memory/<id>` vs `~/.claude/projects/<new-slug>`) — don't try to
unify them. Also add the `workflow-registry.md` row (see above).

## Not the same as `--bare`

The `--bare` CLI flag is a headless `-p` minimal-execution mode (skips hooks,
LSP, plugin sync; disables auto-memory). It has nothing to do with a bare git
repo. Claude has no special bare-repo mode — it simply runs inside whichever
worktree is its cwd.
