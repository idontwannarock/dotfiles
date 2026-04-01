---
name: worklog:daily
description: 管理 Daily To Do — 寫 [daily-todo]/[daily-done] Comment 到 daily Issue。當使用者提到 daily to do、今日待辦、新增/完成/查看待辦項目、今天要做什麼、待辦清單，或用 /worklog:daily 時觸發。也適用於早上開工規劃或下班前確認進度。
---

# Worklog Daily — Daily To Do 管理

透過寫 GitHub Issue Comment 管理今日待辦，由 generate-worklog workflow 自動彙整到 worklog。

## 設定

`github-repo` 從全域 CLAUDE.md 的 Worklog 段落取得（已在 context 中，不需讀取檔案）。

## 操作

| 操作 | 用法 | 說明 |
|------|------|------|
| `add` | `/worklog:daily add KWS: benchmark script` | 寫入 `[daily-todo]` Comment |
| `done` | `/worklog:daily done KWS 重構` | 寫入 `[daily-done]` Comment |
| `list` | `/worklog:daily list` | 列出今天所有 todo/done 狀態 |

支援複合操作：`/worklog:daily add 交接 BEV, done KWS 重構`

## 執行流程

### 1. 取得 github-repo

從 CLAUDE.md 的 Worklog 段落取得 `github-repo`（已在 context 中）。

### 2. 找到今天的 Daily Issue

用 `gh api repos/{github-repo}/issues` 查詢：
- state: open
- labels: daily
- title 符合 `YYYY-MM-DD Worklog`（今天日期）

若不存在，提示：
> 今天的 Daily Issue 還沒建立，請先執行 `gh workflow run create-daily.yml`

### 3. 執行操作

#### `list` 操作

用 `gh api repos/{github-repo}/issues/{number}/comments?per_page=100` 取得今天 Daily Issue 的所有 Comments。

從 Comments 中提取 `[daily-todo]` 和 `[daily-done]` 標記的項目，呈現為清單：
```
今日待辦：
- [ ] KWS: benchmark script
- [x] KWS 重構
```

以 `[daily-done]` 的描述模糊比對 `[daily-todo]` 來判斷完成狀態（包含即算配對）。

#### `add` / `done` 操作

用 `gh api repos/{github-repo}/issues/{number}/comments` POST 寫入：

- `add` → Comment body: `[daily-todo] {描述}`
- `done` → Comment body: `[daily-done] {描述}`

### 4. 確認

輸出：
- 執行了什麼操作（list 則輸出清單）
- Comment URL（add/done 時）
