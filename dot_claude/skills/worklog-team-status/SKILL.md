---
name: worklog:team-status
description: 查詢 Jira + Confluence 彙整團隊現況，結果寫到 GitHub Issue Comment。當使用者提到 team status、團隊狀態、查 Jira，或用 /worklog:team-status 時觸發。
---

# Team Status 彙整

查詢團隊 Jira tickets 與 Confluence 進度頁，按人彙整現況。

## 設定

- 公司名稱預設 `shoalter`，可用 `/worklog:team-status [company]` 覆寫
- 組員清單：`{company}/team.md`
- Slack channel 搜尋：可選，用 `/worklog:team-status --slack #channel-name` 觸發

## 執行流程

### 1. 初始化

讀取 `{company}/team.md` 取得成員清單與 Jira account IDs。
讀取 `{company}/atlassian-config.md` 取得 Jira/Confluence 環境配置。

### 2. 查詢 Jira

讀取 `references/jql-templates.md` 取得 JQL 模板。
用 team.md 的 account IDs 和 atlassian-config.md 的 projects 填入 placeholder。
讀取 `references/jira-query.md` 取得查詢執行方式。
執行查詢，依 Dev PIC 優先、assignee 備援分組。
讀取 `references/status-mapping.md` 將 Jira 狀態轉為 worklog tag。

### 2.5 比對 worklog 缺失票（Stale Ticket Reconciliation）

若有存取今日 worklog（從 worklog:start/end 呼叫，或獨立執行時 worklog 存在）：

1. 提取 worklog Team 區塊中所有 ticket key（如 `CBK-155`、`MC-864`）
2. 與步驟 2 的 Jira 結果比對，找出「worklog 有但 Jira 結果沒有」的 ticket keys
3. 對缺失票執行 `references/jql-templates.md` 的 **Stale Ticket Lookup** JQL 查詢
4. 依 `references/stale-ticket-handling.md` 判斷原因並記錄到異動紀錄

### 3. 讀取 Confluence

讀取 `references/confluence-parse.md` 取得解析邏輯。
用 atlassian-config.md 的 page ID 取得 latest 頁內容。
依成員 heading 拆分，提取各類項目。

### 4. 跟隨 Slack 連結

若 Confluence 內容含 Slack 連結：
讀取 `{company}/slack-config.md` 取得 workspace 設定。
讀取 `references/slack-thread.md` 取得讀取與摘要流程。
逐一讀取 thread 並產生摘要。

### 5. [可選] 搜尋 Slack Channel

僅在指定 `--slack` 參數時執行。
依 `references/slack-thread.md` 的 Channel 搜尋段落執行。

### 6. 合併輸出

讀取 `references/output-format.md` 取得格式規範。
合併所有來源資料，按人輸出。
標記差異。

### 7. 寫入 Issue Comment

讀取 `~/.claude/worklog-config.md` 取得 `github-repo`。

尋找目標 Issue（優先順序）：
1. Open Issue 標題包含「團隊管理」→ 寫到該 Issue
2. 找不到 → 寫到今天的 Daily Issue（title 為 `YYYY-MM-DD Worklog`）
3. 都找不到 → 輸出到終端，提示使用者先建 Issue

Comment body 格式：
```
[team-status]

## Team（Jira 自動查詢 YYYY-MM-DD）

### 成員名稱
- [status] 專案: 項目描述
...
```

用 `gh api repos/{github-repo}/issues/{number}/comments` 寫入。
