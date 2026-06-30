## ADDED Requirements

### Requirement: chezmoi apply 持續追蹤並更新 Rust stable toolchain

系統 SHALL 在每次 `chezmoi apply` 透過跨平台的純 `run_` 腳本（`run_update-rust-toolchain.ps1.tmpl` 與 `run_update-rust-toolchain.sh.tmpl`）執行 `rustup update stable`，使 stable toolchain 持續保持最新。腳本 MUST NOT 使用 `run_once_` 或 `run_onchange_` 前綴（兩者皆無法達成「每次 apply 都更新」）。安裝 rustup 本身 NOT 屬於本 capability，仍由既有 bootstrap 負責。

#### Scenario: 已安裝 rustup 時更新 stable
- **WHEN** `chezmoi apply` 執行，且 `rustup` 存在於 PATH
- **THEN** 腳本執行 `rustup update stable`，stable toolchain 被更新到當前最新版本

#### Scenario: 每次 apply 都會重跑
- **WHEN** 連續兩次 `chezmoi apply`（腳本內容未變）
- **THEN** 兩次都執行更新動作（驗證使用純 `run_` 而非 `run_once_`/`run_onchange_`）

### Requirement: 無 rustup 的機器上無害跳過

系統 SHALL 在腳本開頭偵測 `rustup` 是否可用（PowerShell 以 `Get-Command rustup`、sh 以 `command -v rustup`）；偵測不到時 MUST 印出可見訊息並以成功狀態結束（exit 0），MUST NOT 嘗試安裝 rustup，MUST NOT 讓 `chezmoi apply` 失敗。

#### Scenario: 未安裝 rustup 時跳過
- **WHEN** `chezmoi apply` 執行，且 PATH 中沒有 `rustup`
- **THEN** 腳本印出跳過訊息並成功結束，apply 流程不中斷、不安裝任何東西

### Requirement: 更新失敗時容錯不中斷 apply

系統 SHALL 在 `rustup update stable` 失敗（例如離線、網路錯誤）時印出 warning，但仍以成功狀態結束，使其餘 chezmoi 設定能繼續部署。

#### Scenario: 離線時更新失敗
- **WHEN** `chezmoi apply` 執行、`rustup` 存在、但無法連線取得更新
- **THEN** 腳本印出 warning 並成功結束（exit 0），不中斷整體 apply
