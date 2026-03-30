---
name: worklog:daily
description: 管理 Daily To Do — 寫 [daily-todo]/[daily-done] Comment 到 daily Issue。當使用者提到 daily to do、今日待辦、新增/完成待辦項目，或用 /worklog:daily 時觸發。
---

# Worklog Daily — Daily To Do 管理

透過寫 GitHub Issue Comment 管理今日待辦，由 generate-worklog workflow 自動彙整到 worklog。

## 設定

讀取 `~/.claude/worklog-config.md` 取得：
- `github-repo`: GitHub repo（如 `idontwannarock/worklogs`）

## 操作

| 操作 | 用法 | Comment 標記 |
|------|------|-------------|
| `add` | `/worklog:daily add KWS: benchmark script` | `[daily-todo]` |
| `done` | `/worklog:daily done KWS 重構` | `[daily-done]` |

支援複合操作：`/worklog:daily add 交接 BEV, done KWS 重構`

## 執行流程

### 1. 讀取設定

讀取 `~/.claude/worklog-config.md` 取得 `github-repo`。

### 2. 找到今天的 Daily Issue

用 `gh api repos/{github-repo}/issues` 查詢：
- state: open
- labels: daily
- title 符合 `YYYY-MM-DD Worklog`（今天日期）

若不存在，提示：
> 今天的 Daily Issue 還沒建立，請先執行 `gh workflow run create-daily.yml`

### 3. 寫入 Comment

對每個操作，用 `gh api repos/{github-repo}/issues/{number}/comments` 寫入：

- `add` → Comment body: `[daily-todo] {描述}`
- `done` → Comment body: `[daily-done] {描述}`

### 4. 確認

輸出：
- 執行了什麼操作
- Comment URL
