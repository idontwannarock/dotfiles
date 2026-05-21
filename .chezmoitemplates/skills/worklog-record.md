---
name: worklog-record
description: Record a work item as a GitHub Issue comment — supports manual invocation or assistant-initiated proposal. **When to proactively propose**: the user finished meaningful work and committed it, a technical exploration or design discussion reached a clear conclusion/decision, or the user signals end-of-conversation — including Chinese phrasings like 「差不多了」、「先這樣」、「今天到這」 — with substantive output this session. **Also applies when** the user explicitly mentions recording work, notes, admin items, OKR, or invokes the worklog-record skill directly. **Do not trigger on** trivial edits (typos, formatting, import reordering), pure Q&A or lookups with no substantive output, or when the user is already working inside the worklog repo (avoid double-recording). When in doubt, ask rather than skip — the user can decline, but missed work is gone.
---

# Worklog Record — 記錄工作項目

將工作紀錄寫為 GitHub Issue Comment，由 generate-worklog workflow 自動彙整到 daily worklog。

## 觸發後的操作守則

- **累積多個 commit 批次提議一次**：對話中連續產生多個 commit 時，不要每次 commit 都打斷提問；等自然段落（功能告一段落、準備收尾）再一次詢問是否記錄全部。
- **在連續 commit 過程中保持安靜**：使用者正在 commit 的節奏裡，等收尾訊號再提；中途打斷會破壞心流。
- **詢問語氣要讓使用者容易拒絕**：例如「這次的工作要記到 worklog 嗎？（不用的話直接說 no）」——不要強迫性列選單。

## 設定

`github-repo` 從 user-level system prompt（Claude: `~/.claude/CLAUDE.md`；Codex: `~/.codex/AGENTS.md`）的 Worklog 段落取得（已在 context 中，不需讀取檔案）。

## 使用方式

### 手動呼叫

```
worklog-record KWS: 完成 replay 測試，原速通過
worklog-record CSEC: 修正 batch job soft delete 邏輯
worklog-record [okr] 解決 cache invalidation 的 edge case
```

### Assistant 主動提議

當對話中完成有意義的工作時，assistant 會詢問是否要記錄到 worklog。

## 執行流程

### 1. 取得 github-repo

從 user-level system prompt 的 Worklog 段落取得 `github-repo`（已在 context 中）。

### 2. 列出 Issues 讓使用者選擇

用 `gh api repos/{github-repo}/issues?state=open&per_page=100` 列出所有 open Issues。
Client-side 過濾掉帶有 `daily` label 的 Issues（gh api 不支援 exclude label）。

呈現選單：
```
請選擇要記錄到哪個 Issue：
1. #1 KWS 重構 [shoalter]
2. #2 團隊管理 [shoalter]
3. (寫到今天的 Daily Issue)
4. (開新 Issue)
```

使用者選一個。如果選 Daily Issue，找今天的 daily Issue（title 為 `YYYY-MM-DD Worklog`）。

### 2a. 開新 Issue（僅在使用者選「開新 Issue」時執行）

從當前對話上下文推斷以下資訊，組成草稿一次呈現給使用者確認：

- **Title**（必填）— 從本次工作內容總結
- **Label** — 用 `gh api repos/{github-repo}/labels` 列出現有 labels，從工作內容判斷最可能的 label
- **描述**（選填）— 從工作內容摘要

若無法從上下文推斷某項，才詢問使用者。

呈現草稿讓使用者確認或修改後，用 `gh api repos/{github-repo}/issues` POST 建立 Issue。建立後以新 Issue 作為本次記錄目標，繼續步驟 4。

### 3. 檢查 Daily Issue 存在

若使用者選了 Daily Issue 但不存在，提示：
> 今天的 Daily Issue 還沒建立，請先執行 `gh workflow run create-daily.yml`

### 4. 寫入 Comment

用 `gh api repos/{github-repo}/issues/{number}/comments` 寫入 Comment。

Comment body 就是使用者提供的內容。如果內容帶 `[okr]` 前綴，保留前綴。

### 5. 確認

輸出寫入的內容、目標 Issue、Comment URL。
