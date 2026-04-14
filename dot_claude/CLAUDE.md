# 全域指令

## Worklog 記錄

Worklog repo: `idontwannarock/worklogs`（所有 worklog skill 共用此值，不需額外設定檔）

當以下情況發生時，主動問使用者是否要記到 worklog：
- 完成有意義的任務且已 commit
- 對話中累積多個 commit 後（批次提議一次，不在連續 commit 過程中打斷）
- 技術探索、設計討論得出明確結論或決策
- 使用者發出結束信號（「差不多了」「先這樣」等）且本次有實質成果

不要在以下情況觸發：
- 瑣碎修改（typo、格式調整）
- 使用者已經在 worklog repo 裡工作（避免重複）
- 連續 commit 過程中（等收尾再問）
- 純粹問答、查資料，沒有實質產出

## Episodic Memory 使用規則

- 探索性搜尋（「有沒有討論過 X」）→ 用 `search-conversations` agent（subagent 處理，保護主 context）
- 精確提取（已知要找什麼）→ 可直接呼叫 `search`，但 `show`/`read` 必須用 pagination（`startLine`/`endLine`），單次不超過 50 行
- 禁止無 pagination 的 `show`/`read` 呼叫
