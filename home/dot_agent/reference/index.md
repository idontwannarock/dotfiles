---
okf_version: "0.2"
---

# Agent reference

Tool-agnostic reference shared by every AI coding tool on this machine
(Claude Code, Codex, …). Deployed by chezmoi from `dot_agent/reference/`;
each tool's top-level prompt (`CLAUDE.md` / `AGENTS.md`) points here by
absolute path so one edit takes effect for all of them.

Loaded on demand — read the file you need, not the whole tree.

# Git layouts

* [Bare + worktree](bare-worktree/) - repos organized as a bare git repo plus
  per-branch worktrees: how to detect the layout, operate in it day to day,
  create it, and how Claude Code's own state behaves under it.

# Workflow

* [Worktree isolation](dev-workflow-isolation.md) - when `active_workflows.md`
  has active or paused rows, isolate the new workflow in its own worktree
  instead of sharing the main repo.

# Local environment

* [Local files](local-files/) - keeping gitignored local files (`.env` and
  friends) available across branches and worktrees, backed by a per-repo
  global store, plus its one-time install.

# Testing

* [好測試 / 壞測試](tdd/tests.md) - 判斷一個測試是資產還是負債的準則：走真實
  介面、讀起來像規格、重構後仍存活。
* [Mock 邊界](tdd/mocking.md) - Mock 只放在系統邊界（網路、時鐘、檔案系統、
  第三方 API），系統內部一律走真實介面。
