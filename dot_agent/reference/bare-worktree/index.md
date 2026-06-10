# Bare + worktree repo reference

Reference for repos organized as a bare git repo plus per-branch worktrees.
Loaded on demand (progressive disclosure) — the pointer lives in your
top-level agent instructions (CLAUDE.md / AGENTS.md), which read this index
when cwd looks like a bare+worktree layout.

This reference is **tool-agnostic** unless a file says otherwise.

## When to read which file

| File | Read it when | Audience |
|------|--------------|----------|
| `operating.md` | You're working inside one of these worktrees day to day — confirm the layout, branch/worktree/stash rules. | any tool |
| `setup.md` | You're creating the layout — fresh clone on a new machine, or converting an existing flat repo. | any tool |
| `claude-state.md` | You need Claude Code's state to behave under this layout — auto-memory, transcripts, per-repo settings, workflow registry, the `--bare` flag. | **Claude-specific** — other tools can skip; add a sibling `<tool>-state.md` if needed |

Start with `operating.md` to confirm you're actually in a bare+worktree layout.
