## Context

目前 `~/.claude/CLAUDE.md` 的「預設工作流程」區段定義了線性的 OpenSpec + Superpowers 流程。流程假設同一時間只有一個任務在進行，沒有隔離、進度追蹤、或跨 session 接手機制。

實際使用情境：
- 不同終端機視窗各開一個 Claude Code session，在同一 repo 並行推進不同任務
- 同一 session 中做到一半發現 blocker，需要暫停切換到另一個任務
- 暫停的流程需要能被另一個 session 接手繼續

## Goals / Non-Goals

**Goals:**
- 所有 OpenSpec 流程在獨立 worktree 上進行，天然隔離
- 透過 auto memory 追蹤所有進行中的流程，任何 session 都能查看全域狀態
- 簡化確認步驟，減少流程啟動的摩擦
- 小型/大型流程路徑差異最小化，只在 superpowers 使用和 review 強度上不同

**Non-Goals:**
- 不修改 OpenSpec CLI 或其標準目錄結構
- 不使用 hook 自動化（先用 CLAUDE.md 指令驅動）
- 不處理跨 repo 的流程管理
- 不處理 Worklog、Episodic Memory 等其他 CLAUDE.md 區段

## Decisions

### 1. Worktree 為 OpenSpec 流程的必要條件

**選擇：** 所有 OpenSpec 流程一律開 worktree，不允許在 main 上直接做。

**替代方案：** 只有多流程並行時才開 worktree → 但無法預知後續是否會有第二個流程，屆時再遷移成本更高。

**理由：** 統一行為、避免 lock file 衝突、支援隨時暫停切換。

### 2. 推進模式決定 opsx 指令

**選擇：** 自動推進 → `opsx:propose`（一次產出所有 artifacts）；逐步確認 → `opsx:new` + `opsx:continue`（逐步產出，每步暫停）。

**替代方案：** 大小型流程決定 opsx 指令 → 但 propose vs new+continue 的本質差異就是「一次性 vs 逐步」，與推進模式語意一致。

**理由：** 減少一個獨立的決策維度，讓推進模式同時控制 skill 暫停頻率和 artifact 產出方式。

### 3. 用 auto memory 追蹤流程進度（非 OpenSpec 標準）

**選擇：** 在各 repo 的 project memory 下維護 `active_workflows.md`，用 `~/.claude/workflow-registry.md` 做路徑對應。

**替代方案 A：** 在 openspec change 目錄加 status file → 破壞 OpenSpec 標準。
**替代方案 B：** 用 hook 自動維護 → hook 是 shell script，難以理解流程語意。

**理由：** 不侵入 OpenSpec、利用現有 memory 機制、Claude 有足夠能力在流程轉換點自動更新。

### 4. Workflow Registry 各機器獨立

**選擇：** `~/.claude/workflow-registry.md` 各機器獨立維護，不透過 dotfiles 同步。

**理由：** Worktree 路徑和 project memory 路徑本質上是各機器特有的，同步無意義且會衝突。Claude 在首次使用時自動偵測並新增。

### 5. Code review 修正走新一輪 change

**選擇：** Review 如需修正，在同一 worktree 上從 opsx:propose/new 開始新一輪 change，產生完整的 proposal/design/specs/tasks。

**替代方案：** 直接在原 change 上修改 → 但已 archived，且修正可能改變設計方向，新 change 保持 spec 完整性。

**理由：** 每個 change 都有完整的 artifact 紀錄，不回頭修改已 archived 的 change。

## Risks / Trade-offs

**[每個小型任務都要開 worktree]** → 可接受的 overhead，換取一致性和並行能力。瑣碎任務（不走 OpenSpec）不受影響。

**[Active workflows index 可能與實際狀態脫節]** → Claude 在 session 開始時讀取 index 會發現不一致（例如 worktree 已被手動刪除），此時應自動清理過期紀錄。

**[Workflow registry 路徑推導依賴 git]** → 使用 `git rev-parse --git-common-dir` 推導主 repo 路徑，在 worktree 環境下可靠。非 git 環境不適用，但 OpenSpec 流程本身就需要 git。
