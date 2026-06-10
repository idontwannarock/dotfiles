# Bare + worktree — Claude Code state

**Claude-specific.** How Claude Code's state behaves under a bare+worktree
layout. Other AI tools can skip this file (add a sibling `<tool>-state.md` if
your tool needs equivalent handling). For the tool-agnostic git mechanics see
`operating.md` and `setup.md`.

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

## Migrating Claude state — memory vs transcripts go to DIFFERENT roots

When converting an existing flat repo (see `setup.md`), migrate Claude's
state too. This is the easy thing to get wrong:

- **Memory → `autoMemoryDirectory`** (`~/.claude/memory/<repo-name>`), *not* the
  cwd-slug `projects/<slug>/memory`. This is the target **even though the global
  CLAUDE.md default writes memory to `projects/<slug>/memory`** — the repo's
  `settings.local.json` override wins, so migrate to (and thereafter write to)
  the override location. The source projects-slug memory is often **empty**, so
  "nothing to copy" ≠ "nothing to do": still establish autoMemoryDirectory as the
  home and scaffold `MEMORY.md` (+ move/write fact files) there.
- **Transcripts → new cwd-slug projects dir** (`~/.claude/projects/<new-slug>/`),
  where `<new-slug>` = the `main/` worktree path with `/`→`-`. Copy the `*.jsonl`
  so `--resume`/`--continue` work at the new location.

Memory and transcripts therefore live under **separate roots by design**
(`~/.claude/memory/<repo>` vs `~/.claude/projects/<new-slug>`) — don't try to
unify them. Also add the `workflow-registry.md` row (see above).

## Not the same as `--bare`

The `--bare` CLI flag is a headless `-p` minimal-execution mode (skips hooks,
LSP, plugin sync; disables auto-memory). It has nothing to do with a bare git
repo. Claude has no special bare-repo mode — it simply runs inside whichever
worktree is its cwd.
