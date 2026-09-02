---
okf_version: "0.2"
---

# Agent reference

Tool-agnostic reference shared by every AI coding tool on this machine
(Claude Code, Codex, …). Deployed by chezmoi from `dot_agent/reference/`, so
one edit takes effect for all of them.

Each tool's prompts and skills link **into this tree by absolute path**, not
through this file — `CLAUDE.md` / `AGENTS.md` point at
`bare-worktree/index.md`, and the `tdd` and `worktree` skills link their leaf
files directly. This index exists to declare `okf_version` and to give the
tree a place where everything in it is listed; it is not on any load path.

Loaded on demand — read the file you need, not the whole tree.

姊妹樹 `~/.agent/local/` 是同一層(machine-level、跨 repo、tool-agnostic)的**非公開**
半邊:不受 chezmoi 管、不在本 repo、不跨機同步。判準是**設定類知識歸它** —— 設定
描述「這個環境長什麼樣」,本質上綁特定機器與平台,即使句子本身看不出是誰的環境;
本 repo 為公開 repo,那類內容不進這棵樹。此處只記存在性,內容不複述,需要時直接讀
`~/.agent/local/index.md`(該檔不存在就代表這台機器沒建過)。

# Git layouts

* [Bare + worktree](bare-worktree/) - repos organized as a bare git repo plus
  per-branch worktrees: how to detect the layout, operate in it day to day,
  create it, why only this architecture is documented, and how Claude Code's
  own state behaves under it.

# Workflow

* [Repo identity](repo-identity.md) - the one definition of a repo's slug, the
  key every per-repo artifact is filed under, and the two shortcuts that name a
  different directory without erroring.
* [Worktree isolation](dev-workflow-isolation.md) - when `active_workflows.md`
  has active or paused rows, isolate the new workflow in its own worktree
  instead of sharing the main repo.

# Local environment

* [Local files](local-files/) - keeping gitignored local files (`.env` and
  friends) available across branches and worktrees, backed by a per-repo
  global store, plus its one-time install.

# Code review

* [Review lenses](review-lenses/) - one file per review perspective, read on
  demand by the `review-*` flows. Plain reference files rather than agents or
  skills, so none of them costs anything until a flow names one.

# Testing

* [好測試 / 壞測試](tdd/tests.md) - 判斷一個測試是資產還是負債的準則：走真實
  介面、讀起來像規格、重構後仍存活。
* [Mock 邊界](tdd/mocking.md) - Mock 只放在系統邊界（網路、時鐘、檔案系統、
  第三方 API），系統內部一律走真實介面。
