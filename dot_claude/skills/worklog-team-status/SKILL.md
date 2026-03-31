---
name: worklog:team-status
description: 觸發 GitHub Actions 更新團隊 Jira 狀態到 per-member issues，然後讀取並呈現。當使用者提到 team status、團隊狀態、查 Jira、團隊進度、成員工作狀況、sprint 狀態，或用 /worklog:team-status 時觸發。也適用於站會前準備、週報整理、想了解團隊成員目前手上有什麼票、誰在忙什麼的場景。即使使用者只說「查一下大家的狀況」或「今天站會要報什麼」也應觸發。
---

# Team Status 查詢

觸發 `update-team-status` workflow 更新 per-member issues，然後讀取呈現。

## 設定

- 公司名稱預設 `shoalter`，可用 `/worklog:team-status [company]` 覆寫
- 組員清單：worklogs repo 的 `{company}/team.md`

## 執行流程

### 1. 初始化

讀取 `~/.claude/worklog-config.md` 取得 `github-repo`。
讀取 worklogs repo 的 `{company}/team.md` 取得成員名稱清單。

### 2. 觸發 workflow 並取得時間戳

記錄觸發前的 UTC 時間戳（`date -u +%Y-%m-%dT%H:%M:%SZ`），然後觸發：
```
gh workflow run update-team-status.yml --repo {github-repo}
```

### 3. 等待完成

先等 5 秒讓 GitHub 排程 run，然後用以下指令輪詢：
```
gh run list --workflow=update-team-status.yml --repo {github-repo} --limit 5 --json databaseId,status,conclusion,createdAt
```

從結果中找 `createdAt` 晚於步驟 2 時間戳的 run（避免誤讀舊 run）。
每 10 秒查一次，最多等 3 分鐘。

- **completed + success**：進入步驟 4
- **completed + failure**：顯示錯誤，提示使用者用 `gh run view {id} --log` 檢查
- **超時**：告知使用者 workflow 未在 3 分鐘內完成，可手動查看

### 4. 讀取 per-member issues

對每位成員，查詢標題為 `Team: {name}` 且有 `team-member` label 的 open issue：
```
gh api repos/{github-repo}/issues --method GET -f state=open -f labels=team-member -f per_page=100
```

**首次執行**：如果查不到 `team-member` issues，這是正常的 — workflow 會在首次執行時自動建立。此時直接告知使用者「per-member issues 已建立，資料已寫入」即可。

讀取每個 issue 的 comments，用陣列索引取前兩個（GitHub API 按建立時間排序）：
```
gh api repos/{github-repo}/issues/{number}/comments --jq '.[0:2]'
```

- `.[0]`（Comment #1）：Active Tasks
- `.[1]`（Comment #2）：Completed

### 5. 呈現

解析 comment 內容：
- `<!-- jira-start -->` 到 `<!-- jira-end -->` 之間的項目是 **Jira 自動產生**的，直接使用
- `### Manual Tasks` 下的項目是**手動新增**的，輸出時加 `(手動)` 前綴以區分

按成員分組輸出到終端：

```
## Team Status（YYYY-MM-DD）

### 成員名稱
**Active:**
- [wip] CBK-155: Checkout refactoring — In Code Review
- [todo] MC-864: Mobile payment flow — Sprint 12
- [wip] (手動) Internal tool: Build deploy dashboard

**Recently Completed:**
- [done] CBK-140: Cart API migration — 2026-03-28
```

### 6. [可選] 寫入 Issue Comment

若使用者要求記錄（或搭配 `/worklog:record` 使用），將結果寫到 daily issue。
不再自動寫入 `[team-status]` comment — per-member issues 本身就是 single source of truth。
