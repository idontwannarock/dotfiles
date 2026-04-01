## Context

`update-team-status.yml` 用 inline JQL 查詢每位成員的 Jira tickets，依賴 `atlassian-config.md` 的 Dev PIC custom field ID（`cf[11563]`），並用 Jira status category mapping 判斷 active/done。此方式有三個問題：

1. Custom field 依賴脆弱 — field ID 變更時 workflow 會靜默失敗
2. Status category mapping 不準 — "Pending for UAT"、"Launch Ready" 等中間狀態被歸為 done
3. 需要兩個 JQL 查詢（active + done 7 天）— 增加 API 呼叫次數和複雜度

現有 per-member issues (#23-#26) 無年份標記，且 Comment #1 內容有錯誤（done items 混在 active 中）。

## Goals / Non-Goals

**Goals:**
- 用 Jira Saved Filter 取代 inline JQL，消除 custom field 依賴
- 用「消失偵測」取代 status category mapping，更準確判斷完成
- Member issue 加年份標記，支援年度績效歸檔
- 清理重建現有 per-member issues

**Non-Goals:**
- Howard 的特殊路由（Phase 2）
- Build Tickets 追蹤（Phase 2）
- 修改 `worklog:team-status` skill 或 `create-daily.yml`
- 修改 `generate-worklog.yml`

## Decisions

### D1: Filter 只替代「人」的部分

Filter 內容定義「哪些 ticket 屬於這個人」，status 過濾（active vs completed）留在 workflow。

**替代方案**：每人建兩個 filter（active + done）→ 否決，因為需要 10 個 filter 且 status 邏輯分散。

### D2: 消失偵測取代 done 查詢

不再用第二個 JQL 查 "status IN (Done, Closed, Resolved)"。改為：
1. 讀 Comment #1 現有 Jira ticket keys
2. 比對 filter 查詢結果
3. 不在 filter 結果中的 = 消失 = 完成（或取消、移走）

**補查最終 status**：消失的 tickets 用 `key IN (KEY-1, KEY-2, ...)` 一次批次查回。

### D3: team.md 保留 jira_id 備用

格式：`<!-- jira: {account_id} | filter: {filter_id} -->`

移除 display name（可變、無查詢用途）。保留 jira_id 供未來 Phase 2 或其他查詢使用。

### D4: 清理重建現有 issues

Close #23-#26，新 workflow 首次執行時自動建立帶年份的新 issue + seed comments。不做漸進式遷移。

### D5: Member issue title 帶年份

格式：`Team: {Name} ({Year})`。Workflow 建立和查詢時都帶年份比對。每年初可建新 issue，舊的 close 歸檔。

## Risks / Trade-offs

- **[首次執行消失偵測為空]** Comment #1 是全新 seed，無既有 items 可比對 → 首次執行只寫入 active，不觸發移動邏輯。無風險。
- **[Filter 權限]** Saved Filter 需要 workflow 的 Jira 帳號有讀取權限 → 已驗證，filter 結果正確。
- **[消失 ≠ 完成]** Ticket 從 filter 消失可能是被移到別的 project 或 reassign → 批次查最終 status 可區分（Done vs 其他），移到 Comment #2 時帶 status 資訊。
- **[舊 issues 資料丟失]** Close #23-#26 會丟失 Comment #2 的 completed 歷史 → 目前 Comment #2 全是 "No completed items yet."，實際無資料損失。
