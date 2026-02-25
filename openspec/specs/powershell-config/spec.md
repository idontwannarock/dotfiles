## ADDED Requirements

### Requirement: PS5 與 PS7 使用獨立 profile 樹
PowerShell 5 與 PowerShell 7 SHALL 各自擁有獨立的 profile 主檔與 `profile.d/` 目錄，路徑分別對應 Windows 的 `~/Documents/WindowsPowerShell/` 與 `~/Documents/PowerShell/`。

#### Scenario: PS7 啟動時載入 PS7 profile
- **WHEN** PowerShell 7 啟動於 Windows
- **THEN** 執行 `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`，載入 PS7 專屬 fragments

#### Scenario: PS5 啟動時載入 PS5 profile
- **WHEN** Windows PowerShell 5 啟動
- **THEN** 執行 `~/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1`，載入 PS5 專屬 fragments

#### Scenario: PS profile 只部署到 Windows
- **WHEN** chezmoi apply 在 macOS 或 Linux 執行
- **THEN** `Documents/` 目錄不被部署

### Requirement: 共用 fragment 抽離至 _shared-profile.d
純相容語法的 PowerShell fragment（不含版本專屬 API）SHALL 放在 `Documents/_shared-profile.d/`，PS5 與 PS7 的 loader 都 source 此目錄。

#### Scenario: PS7 載入 shared fragments
- **WHEN** PS7 profile 的 loader 執行
- **THEN** `~/Documents/_shared-profile.d/` 下所有 `.ps1` 按名稱排序後依序執行

#### Scenario: PS5 載入 shared fragments
- **WHEN** PS5 profile 的 loader 執行
- **THEN** `~/Documents/_shared-profile.d/` 下所有 `.ps1` 按名稱排序後依序執行

### Requirement: PS7 profile 使用 PS7 專屬語法
PS7 專屬的 `profile.d/` 內 fragments SHALL 可使用 PowerShell 7+ 語法（ternary operator `? :`、null coalescing `??=`、`using module` 等），不需要相容 PS5。

#### Scenario: PS7 fragment 可使用 ternary
- **WHEN** PS7 啟動並載入 profile.d fragment
- **THEN** 使用 `$x ? $a : $b` 語法的 fragment 正常執行無錯誤

### Requirement: PowerShell profile 包含自動 fetch 提示機制
Shared fragment 中 SHALL 包含與 shell_common 相同邏輯的自動 fetch 提示，每天最多執行一次。

#### Scenario: PS7 啟動時觸發 fetch 檢查
- **WHEN** PowerShell 7 啟動，且 flag 檔日期不是今天
- **THEN** 執行 fetch 並在有新版本時顯示提示訊息
