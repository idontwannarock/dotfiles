## ADDED Requirements

### Requirement: Pester 測試由 GitHub Actions 在 Windows runner 上自動執行

repo 中的 PowerShell 腳本測試（`tests/*.Tests.ps1`）SHALL 由 GitHub Actions workflow 在 `windows-latest` runner 上以 Pester 5 執行。測試失敗 SHALL 使 workflow 失敗。

Workflow SHALL 在 push 到 main 與 pull request 時觸發，且 SHALL 以 `paths` filter 限定於「測試本身」與「被測腳本所在目錄」的變動，避免與測試無關的 dotfile 變更觸發 Windows runner。

#### Scenario: 測試檔變更時觸發

- **WHEN** 包含 `tests/` 下變更的 commit push 到 main 或開啟 pull request
- **THEN** Pester workflow 觸發，在 `windows-latest` 上執行 `tests/` 內所有 `*.Tests.ps1`

#### Scenario: 被測腳本變更時觸發

- **WHEN** 包含 `home/dot_local/bin/` 下變更的 commit push 到 main 或開啟 pull request
- **THEN** Pester workflow 觸發

#### Scenario: 無關變更不觸發

- **WHEN** push 的 commit 只含 `docs/`、`openspec/` 或 `home/` 其他子目錄的變更
- **THEN** Pester workflow 不觸發

#### Scenario: 測試失敗使 workflow 失敗

- **WHEN** 任一 Pester 測試 assertion 失敗
- **THEN** workflow step 以非零 exit code 結束，CI 顯示失敗

#### Scenario: 測試相對路徑假設成立

- **WHEN** Pester 測試以 `Split-Path -Parent $PSScriptRoot` 推導 repo root 並定位被測腳本
- **THEN** 該推導成立，亦即 `tests/` SHALL 維持在 repo root 的下一層，不得再下沉一層目錄
