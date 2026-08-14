## 1. Spec 正名

- [x] 1.1 `openspec/specs/workflow-concurrency/spec.md` 第三欄改為 `Active Workflows Path`，requirement 敘述同步
- [x] 1.2 加上 `Repo` 欄為正典 slug 的斷言，並指向 `principles.md` 的定義（不複述定義）
- [x] 1.3 加上「同一 repo 的產物必須落在同一處」scenario
- [x] 1.4 兩則既有 scenario（首次開啟、worktree 查詢）的措辭跟著改為 active-workflows 路徑
- [x] 1.5 `openspec validate --all` 全綠（37/37）

## 2. 確認 body 不需修改

- [x] 2.1 對照 `home/.chezmoitemplates/skills/dev-workflow.md` 的 2b、ARCH dispatch table、bare-worktree 說明三處，確認皆已使用 active-workflows 說法
      → 三處內文皆正確，但發現第四處殘留：body 第 41 行按標題名交叉引用
        `dot_agent/reference/bare-worktree/claude-state.md` 的章節「Workflow registry & project-memory path」，
        而該章節內文早已改用 Active-workflows Path，只有標題沒改。標題與引用一併更新。

## 3. 本機資料遷移（`~/.agent/`，不在版控）

- [x] 3.1 遷移前記錄三個非正典目錄的完整內容
      → `shoalter-ai-toolkit/` 含一列 `add-self-service-setup-wizard`（2026-06-16）；另兩個僅有表頭。
- [x] 3.2 `~/.agent/workflow-registry.md` 表頭改為 `Active Workflows Path`
- [x] 3.3 `Repo` 欄全部正規化為正典 slug（10 列）
- [x] 3.4 第 5–7 列的 project memory 路徑改為對應的 active-workflows 路徑
- [x] 3.5 合併分裂目錄：`sensitive-content` 無正典目錄，改名即合併；`keyword-search` 正典已存在且非正典僅表頭
- [x] 3.6 移除已死的 `add-self-service-setup-wizard` 列
      → 兩項獨立證據：worktree 目錄不存在，且該分支在 `.bare` 的 `worktree list` 與 branch 清單皆查無。
- [x] 3.7 刪除三個非正典目錄
- [x] 3.8 驗收：每列的 slug 與 Active Workflows Path 一致、Main Repo Path 皆存在、無非正典目錄殘留
      → 全數通過。10 列對 9 個目錄，差額為 `ai-tools-list`——該 repo 從未跑過流程，
        `active_workflows.md` 於首次使用時建立，非缺陷。
