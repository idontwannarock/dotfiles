---
name: record-worklog
description: 從任何專案記錄工作項目到 daily worklog — 支援手動呼叫或 Claude 主動提議
---

# Record Worklog

從任何專案將工作紀錄寫入 daily worklog 檔案。

## 設定

讀取 `~/.claude/worklog-config.md` 取得：
- `repo`: worklog repo 的絕對路徑
- `company`: 公司名稱（用於定位檔案路徑）

## 使用方式

### 手動呼叫

```
/record-worklog KWS: 完成 replay 測試，原速通過
/record-worklog CSEC: 修正 batch job soft delete 邏輯
```

### Claude 主動提議

當對話中完成有意義的工作時，Claude 會詢問是否要記錄到 worklog。

## 執行流程

### 1. 讀取設定

讀取 `~/.claude/worklog-config.md` 取得 repo 路徑和 company。
若檔案不存在，提示使用者建立。

### 2. 定位今日 worklog

路徑格式：`{repo}/{company}/{YYYY}/{YYYYMM}/{YYYYMMDD}.md`
- 檔案存在 → 直接使用
- 檔案不存在 → 提示使用者先執行 `/daily-worklog` 建檔

### 3. 判斷寫入位置

根據內容判斷寫入哪個區塊：

| 關鍵字或 context | 目標區塊 |
|---|---|
| 有明確的專案/技術主題 | `## 筆記` 下的對應 `### {主題}` 子區塊 |
| 是待辦事項 | `## Daily To Do`（加為 `- [ ]` 項目） |
| 是行政/管理事項 | `## Administration` |
| 無法判斷 | 詢問使用者 |

### 4. 寫入

- 追加到對應區塊末尾
- 保持現有格式（不改動其他內容）
- 若參數中已包含完整描述，直接寫入
- 若從對話 context 產生，先摘要再確認後寫入

### 5. 確認

輸出寫入的內容和位置，讓使用者確認。
