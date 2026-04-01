## Why

目前 CLAUDE.md 的工作流程設計假設同一時間只有一個流程在推進。實際使用中，經常需要在同一個 repo 並行推進多個任務（不同 session 各跑一個流程，或同一 session 中暫停切換），現有流程沒有隔離機制、進度追蹤、或跨 session 接手的能力。

## What Changes

- **合併確認步驟**：三步確認（流程、規模、推進模式）改為一次問完
- **Worktree 必選**：所有 OpenSpec 流程一律在獨立 worktree 上進行，避免 lock file 衝突
- **流程路徑重整**：小型流程去掉 brainstorming 和 superpowers skills（由 opsx 直接處理設計）；大型流程保留完整 superpowers 流程
- **推進模式決定 opsx 指令**：自動推進用 `opsx:propose`，逐步確認用 `opsx:new` + `opsx:continue`
- **Code review 必做**：小型用 `code:review-quick`，大型用 `code:review-full`；review 修正走新一輪 change（同 worktree）
- **新增多流程管理機制**：`~/.claude/workflow-registry.md`（repo 路徑對應表）+ 各 repo project memory 下的 `active_workflows.md`（進行中流程清單）
- **流程進度記錄**：每個 skill 轉換點自動更新 active workflows，支援跨 session 接手

## Capabilities

### New Capabilities
- `workflow-concurrency`: 多流程並行管理機制 — workflow registry、active workflows index、跨 session 接手

### Modified Capabilities
- `workflow-instructions`: 確認步驟合併、worktree 必選、流程路徑重整、code review 必做、推進模式與 opsx 指令連動

## Impact

- `~/.claude/CLAUDE.md`（chezmoi source: `dot_claude/CLAUDE.md`）— 預設工作流程區段重寫
- `~/.claude/workflow-registry.md` — 新檔案，各機器獨立不同步
- 各 repo 的 project memory `active_workflows.md` — 新檔案，由 Claude 自動維護
- `openspec/specs/workflow-instructions/spec.md` — 需更新以反映新流程
