## Why

`update-team-status.yml` workflow 目前用 inline JQL（Dev PIC + assignee）查詢每位成員的 Jira tickets，需要依賴 `atlassian-config.md` 的 custom field ID，且用 status category mapping 判斷完成狀態容易誤判（如 "Pending for UAT" 被歸為 done）。改用 Jira Saved Filters 可簡化查詢、消除 custom field 依賴，並用更可靠的「消失偵測」取代 status mapping。

同時，現有 per-member issues 缺少年份標記，無法整合年度績效考核流程，且內容有錯誤需要清理重建。

## What Changes

- team.md 格式加入 `filter:` 欄位，移除 display name
- Workflow JQL 改用 `filter = {filterId}` 取代 inline Dev PIC/assignee 查詢
- 移除 done JQL 查詢，改用「比對 filter 結果 vs Comment #1 現有 items」的消失偵測
- 消失的 tickets 用 `key IN (...)` 批次查最終 status 後移到 Comment #2
- 移除 `atlassian-config.md` 的 Dev PIC / Test PIC field 讀取
- 移除 status category mapping 邏輯
- Member issue title 改為 `Team: {Name} ({Year})` 格式
- **BREAKING**: 現有 per-member issues (#23-#26) 需 close，由新 workflow 重建

## Capabilities

### New Capabilities
- `filter-based-query`: 用 Jira Saved Filter 查詢成員 active tickets，取代 inline JQL
- `disappeared-ticket-detection`: 偵測從 filter 結果消失的 tickets 並移到 completed，附帶最終 Jira status
- `yearly-member-issues`: Per-member issue 帶年份標記，支援年度歸檔

### Modified Capabilities

## Impact

- `shoalter/team.md`: 格式變更（加 filter ID，移除 display name）
- `.github/workflows/update-team-status.yml`: 查詢邏輯重寫
- `shoalter/atlassian-config.md`: Dev PIC / Test PIC field 不再被此 workflow 讀取（其他 workflow 可能仍需要）
- Per-member issues #23-#26: 需 close 並重建
- `worklog:team-status` skill (dotfiles repo): 不需改動（workflow 介面不變）
