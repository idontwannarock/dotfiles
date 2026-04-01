## 1. team.md 格式更新

- [x] 1.1 更新 `shoalter/team.md`：每位成員加入 `filter:` 欄位，移除 display name

## 2. Workflow Parse 邏輯

- [x] 2.1 修改 "Parse team config" step：regex 改為抽取 `name`、`jira_id`、`filter_id`，缺少 filter 時 warning 並跳過
- [x] 2.2 移除 `atlassian-config.md` 的 Dev PIC / Test PIC field 讀取（保留 cloud ID 讀取）

## 3. Filter 查詢

- [x] 3.1 改寫 "Query Jira for each member" step：用 `filter = {filterId}` 取代 inline JQL
- [x] 3.2 移除第二個 done JQL 查詢
- [x] 3.3 移除 status category mapping 邏輯（`status_map` step）

## 4. 消失偵測與移動

- [x] 4.1 在 "Update per-member issue comments" step 中：parse Comment #1 現有 Jira ticket keys
- [x] 4.2 比對 filter 結果，找出消失的 keys
- [x] 4.3 消失 keys 非空時，用 `key IN (...)` 批次查詢最終 status
- [x] 4.4 消失 tickets append 到 Comment #2（格式：`- [done] KEY: Summary — Status — Date`）
- [x] 4.5 處理邊界：首次執行（無既有 keys）跳過偵測、查詢失敗時 status 標記為 Unknown

## 5. Yearly Member Issues

- [x] 5.1 修改 "Ensure per-member issues exist" step：title 改為 `Team: {Name} ({Year})`，年份用台北時區
- [x] 5.2 查詢邏輯改為比對帶年份的 title

## 6. 清理與部署

- [x] 6.1 Close 現有 per-member issues #23-#26
- [x] 6.2 Commit 並 push workflow 和 team.md 變更到 worklogs repo
- [x] 6.3 手動觸發 workflow 驗證首次執行：建立新 issues + seed comments + 寫入 active tickets
