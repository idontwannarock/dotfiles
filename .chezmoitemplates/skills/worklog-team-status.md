---
name: worklog-team-status
description: 觸發 GitHub Actions 更新團隊 Jira 狀態到 per-member issues，然後讀取並呈現。當使用者提到 team status、團隊狀態、查 Jira、團隊進度、成員工作狀況、sprint 狀態，或呼叫 worklog-team-status skill 時觸發。也適用於站會前準備、週報整理、想了解團隊成員目前手上有什麼票、誰在忙什麼的場景。即使使用者只說「查一下大家的狀況」或「今天站會要報什麼」也應觸發。
---

# Team Status 查詢

觸發 `update-team-status` workflow 更新 per-member issues，然後讀取呈現。

## 設定

`github-repo` 從 user-level system prompt（Claude: `~/.claude/CLAUDE.md`；Codex: `~/.codex/AGENTS.md`）的 Worklog 段落取得（已在 context 中，不需讀取檔案）。
成員清單從 `team-member` label 的 GitHub Issues 動態取得（不需讀取本地檔案）。

## 執行流程

### 1. 取得 github-repo

從 user-level system prompt 的 Worklog 段落取得 `github-repo`（已在 context 中）。

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

查詢所有帶 `team-member` label 的 open issues（不需事先知道成員名稱）：
```
gh api repos/{github-repo}/issues --method GET -f state=open -f labels=team-member -f per_page=100
```

從每個 issue 的 title 提取成員名稱（格式：`Team: {name}`）。

**首次執行**：如果查不到 `team-member` issues，這是正常的 — workflow 會在首次執行時自動建立。此時直接告知使用者「per-member issues 已建立，資料已寫入」即可。

讀取每個 issue 的 comments，用陣列索引取前兩個（GitHub API 按建立時間排序）：
```
gh api repos/{github-repo}/issues/{number}/comments --jq '.[0:2]'
```

- `.[0]`（Comment #1）：Active Tasks
- `.[1]`（Comment #2）：Completed

### 5. 呈現

解析 comment 內容：
- `<!-- jira-start -->` 到 `<!-- jira-end -->` 之間的項目是 **Jira 自動產生**的（已按狀態分組），直接使用
- `### Manual Tasks` 下的項目是**手動新增**的，輸出時加 `(手動)` 前綴以區分

按成員分組輸出到終端，保留 comment 中的分組格式：

```
## Team Status（YYYY-MM-DD）

### Charlie
🔨 **In Progress** (1)
- MC-958: [BE] replace salesforce case number to zendesk ticket id

📋 **To Do** (3)
- MC-964: [BE] set configuration param value to zendesk
- MC-962: [BE] 1st patch zendesk_ticket_id (before Apr 10)
- MC-963: [BE] 2st patch zendesk_ticket_id

⏳ **Waiting for Development** (3)
- GCS-252: [HKTVmall] Support Private Chatroom
- GCS-247: [HKTVmall] Live CMS ChicChat
- GCS-253: [HKTVmall] Online User System - SHIP

📬 **Open** (2)
- MP-38: Crawl HKTVmore Blog
- MC-947: [BE][Support chat] Remove API controller logic

**(手動)**
- Internal tool: Build deploy dashboard

**Recently Completed:**
- CBK-140: Cart API migration — Done — 2026-03-28
```

### 6. [可選] 寫入 Issue Comment

若使用者要求記錄（或搭配 `worklog-record` skill 使用），將結果寫到 daily issue。
不再自動寫入 `[team-status]` comment — per-member issues 本身就是 single source of truth。

## 注意事項

- 此 skill 不讀取任何本地檔案（無 worklog-config.md、無 team.md、無 references/）
- 所有資料來源：user-level system prompt context（github-repo）+ GitHub API（issues）+ workflow（Jira 查詢）
