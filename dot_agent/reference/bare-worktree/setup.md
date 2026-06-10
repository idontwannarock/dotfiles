# Bare + worktree — creating the layout

Tool-agnostic. How to create a bare+worktree layout, either fresh on a new
machine or by converting an existing flat repo. For daily-use rules see
`operating.md`.

## Bootstrapping on a new machine

```bash
mkdir <repo> && cd <repo>
git clone --bare <url> .bare
git --git-dir=.bare config core.hooksPath .githooks
git --git-dir=.bare worktree add main main      # fires post-checkout hook
```

## Converting an existing flat repo (local, no remote)

A normal repo becomes bare+worktree entirely locally — no remote needed; `.bare/`
*is* the database the old `.git/` was. Clone-based is safest (keeps the original
until verified):

```bash
cd <parent>
mv <repo> _convert_src                         # backup until verified
mkdir <repo> && cd <repo>
git clone --bare ../_convert_src .bare         # full history, from local
git --git-dir=.bare remote remove origin       # clone adds origin → drop if no remote wanted
git --git-dir=.bare worktree add main main
mv ../_convert_src/<gitignored-data> main/...  # move irreplaceable ignored files
# verify main/ + `git log`, then: rm -rf ../_convert_src
```

- **`.venv` can't be moved** — `pyvenv.cfg`/shebangs hardcode the absolute path;
  rebuild with `uv sync`. Data files (CSV/parquet) move fine.
- Only move **gitignored-but-irreplaceable** files (e.g. large local datasets);
  regenerable ones (`.codegraph`, `__pycache__`, logs) don't need moving.

When converting a repo you use with Claude Code, also migrate Claude's state —
memory and transcripts go to **different roots**. See `claude-state.md` →
"Migrating Claude state".
