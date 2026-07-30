# Local files

Keeping gitignored local files (`.env`, `.env.local`, `.env.*.local`) available
across branches and worktrees of a repo. Tool-agnostic.

* [Local files store](store.md) - how gitignored local files stay available
  across branches and worktrees, backed by a per-repo global store. Start here
  — it holds the authority model, store layout, the `localfiles` helper, and
  the agent read-fallback rule.
* [Local files install & setup](setup.md) - one-time install of the global
  `core.hooksPath` dispatcher and the `localfiles` helper via chezmoi, plus
  migration notes for older bare+worktree repos.
