---
name: worklog:record
description: 記錄工作項目到 GitHub Issue Comment — 支援手動呼叫或 Claude 主動提議。當使用者提到記錄工作、筆記、行政事項、OKR，或用 /worklog:record 時觸發。
---

# Worklog Record — 記錄工作項目

將工作紀錄寫為 GitHub Issue Comment，由 generate-worklog workflow 自動彙整到 daily worklog。

## 設定

讀取 `~/.claude/worklog-config.md` 取得：
- `github-repo`: GitHub repo（如 `idontwannarock/worklogs`）

## 使用方式

### 手動呼叫

```
/worklog:record KWS: 完成 replay 測試，原速通過
/worklog:record CSEC: 修正 batch job soft delete 邏輯
/worklog:record [okr] 解決 cache invalidation 的 edge case
```

### Claude 主動提議

當對話中完成有意義的工作時，Claude 會詢問是否要記錄到 worklog。

## 執行流程

### 1. 讀取設定

讀取 `~/.claude/worklog-config.md` 取得 `github-repo`。
若檔案不存在或缺少 `github-repo`，提示使用者建立。

### 2. 列出 Issues 讓使用者選擇

用 `gh api repos/{github-repo}/issues` 列出所有 open Issues（排除 `daily` label）。

呈現選單：
```
請選擇要記錄到哪個 Issue：
1. #1 KWS 重構 [shoalter]
2. #2 團隊管理 [shoalter]
3. (寫到今天的 Daily Issue)
```

使用者選一個。如果選 Daily Issue，找今天的 daily Issue（title 為 `YYYY-MM-DD Worklog`）。

### 3. 檢查 Daily Issue 存在

若使用者選了 Daily Issue 但不存在，提示：
> 今天的 Daily Issue 還沒建立，請先執行 `gh workflow run create-daily.yml`

### 4. 寫入 Comment

用 `gh api repos/{github-repo}/issues/{number}/comments` 寫入 Comment。

Comment body 就是使用者提供的內容。如果內容帶 `[okr]` 前綴，保留前綴。

### 5. 確認

輸出寫入的內容、目標 Issue、Comment URL。
