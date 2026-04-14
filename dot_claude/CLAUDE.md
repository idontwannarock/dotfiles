# 全域指令

## Worklog 記錄

Worklog repo: `idontwannarock/worklogs`（所有 worklog skill 共用此值，不需額外設定檔）

## Episodic Memory 使用規則

- 探索性搜尋（「有沒有討論過 X」）→ 用 `search-conversations` agent（subagent 處理，保護主 context）
- 精確提取（已知要找什麼）→ 可直接呼叫 `search`，但 `show`/`read` 必須用 pagination（`startLine`/`endLine`），單次不超過 50 行
- 禁止無 pagination 的 `show`/`read` 呼叫
