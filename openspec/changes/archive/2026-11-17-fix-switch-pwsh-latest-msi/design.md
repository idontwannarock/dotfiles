## Context

`switch-pwsh-to-msi.ps1` 呼叫 `https://api.github.com/repos/PowerShell/PowerShell/releases/latest`，再找 `win-x64.msi` asset。`releases/latest` 回傳最新穩定版。從 7.7.0 起官方不出 MSI，所以 `latest` 是沒有 MSI 的 v7.7.0，helper 報錯結束。7.6 是 LTS，仍有 MSI（v7.6.10）。

repo 已有 Pester 測試（`tests/chezmoi-guard.Tests.ps1`）。`.github/workflows/test-pester.yml` 在 `home/dot_local/bin/**` 變動時會執行。

## Goals / Non-Goals

**Goals:**
- helper 在最新穩定版沒有 MSI 時，改選最新一個有 MSI 的穩定版。
- 選擇邏輯可用不連網的 fixture 測試。

**Non-Goals:**
- 不改下載後的流程（簽章驗證、`msiexec`、移除 MSIX、驗證路徑）。
- 不支援 arm64 或 x86。
- 不處理「MSI 版升級」的 winget 問題，那在 `docs/powershell.md` 說明。
- 不把 pwsh 留在 7.6.x 的政策寫進 helper：helper 只負責「裝得到的最新 MSI」。

## Decisions

### D1：列出 releases，過濾後取版本號最高者

改呼叫 `releases?per_page=100`，在 helper 內做：排除 `prerelease` 與 `draft` → 只留有 `win-x64\.msi$` asset 的 → 依 `tag_name` 轉成 `[version]` 後由高到低排序 → 取第一個。

為什麼：
- `releases/latest` 一次只回一個，沒有 MSI 就沒有退路。
- 不能只取清單的第一個含 MSI 的項目。清單依發布時間排序，維護分支（7.4.x、7.5.x）可能晚於 7.6.x 發布。依版本號排序才穩定。
- 必須用 `[version]` 比較。字串比較會把 `7.6.9` 排在 `7.6.10` 之後。

替代方案：
- 固定寫死 `v7.6.10`：每次 7.6.x 更新都要改腳本，不採用。
- 只看 `7.6.*`：7.6 之後若又有含 MSI 的版本會被誤擋，不採用。

### D2：選擇邏輯放在 helper 內的一個函式 `Select-MsiRelease`

函式接收 release 物件陣列，回傳被選中的 release（或 `$null`）。主流程呼叫它。

為什麼：函式沒有網路和系統副作用，可用 fixture 測試。測試用 PowerShell 的 AST（`[Management.Automation.Language.Parser]::ParseFile`）把函式從腳本取出再執行，所以不需要改腳本的整體結構，也不會執行腳本主流程（它需要提權）。

替代方案：把函式拆到獨立檔案。helper 要能單檔部署到 `~/.local/bin`，拆檔會增加部署複雜度，不採用。

### D3：找不到 MSI 時，在移除 MSIX 之前中止

原本的順序已經是「先裝 MSI，再移除 MSIX」。選擇步驟在最前面，`$null` 時 `throw`，所以不會走到移除步驟。

### D4：版本較舊時印說明

比較「所選版本」與「最新穩定版（不論有沒有 MSI）」。若不同，印一行：最新穩定版是 X，它沒有 MSI，改裝 Y。這讓使用者知道自己沒有拿到最新版。

## Risks / Trade-offs

- [GitHub API 未登入每小時 60 次] → 手動執行一次只用 1 次呼叫，遠低於限制。
- [`per_page=100` 不夠含到有 MSI 的版本] → 目前 7.6.x 在前 20 筆內。若真的沒找到，helper 會報錯並中止（D3）。
- [7.6 LTS 結束後不再有新 MSI] → helper 會一直選到最後一個有 MSI 的版本，並印出 D4 的說明。這是預期行為。
