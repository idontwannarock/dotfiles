## Why

Statusline 目前依賴 ccusage CLI 取得 block info 和 burn rate，但 ccusage 慢（3-5 秒）且在某些環境無法使用。參考 ccstatusline 專案，許多資訊可以直接從 JSONL 檔案計算，無需外部 CLI。同時缺少 token speed 和 git diff 統計等實用資訊。

## What Changes

- 新增 token speed 計算（從 session JSONL 解析 output tokens/sec）
- 新增 block timer（從 JSONL timestamps 計算 5hr block，取代 ccusage blocks）
- 新增 git insertions/deletions 顯示
- 改用多層 cache 架構（memory + file + rate limit）
- 移除 ccusage blocks 依賴（burn rate 改用 today cost / block elapsed 近似）
- 保留 ccusage daily 用於 today cost（無替代方案）

## Capabilities

### New Capabilities

- `statusline-token-speed`: 從 JSONL 計算並顯示 output tokens/sec
- `statusline-block-timer`: 從 JSONL 計算 5hr block elapsed/remaining，取代 ccusage blocks
- `statusline-git-diff-stats`: 顯示 git insertions/deletions
- `statusline-multi-cache`: memory + file 多層 cache 架構

### Modified Capabilities

- `statusline-ccusage-resolution`: 移除 block info 的 ccusage 依賴，burn rate 改用近似計算
- `statusline-release`: statusline.go 變更觸發 CI 重新編譯

## Impact

- `claude/statusline/statusline.go` — 主要改動
- 移除 `fetchBlockInfo()` 對 ccusage 的呼叫
- 新增 JSONL 檔案讀取邏輯
- 輸出格式變化（line 1 加 git diff stats + token speed，line 2 block timer 改為 JSONL 計算）
