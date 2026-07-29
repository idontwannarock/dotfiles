# pester-test-ci Specification

## Purpose
規範 repo 內 PowerShell 腳本測試（`tests/*.Tests.ps1`）的 CI 契約：由 GitHub Actions 在 `windows-latest` 上以 Pester 5 執行、僅在針對 `main` 的 pull request 觸發、以 `paths` filter 限定於測試本身與被測腳本所在目錄，測試失敗即讓 workflow 變紅。

## Requirements

### Requirement: Pester 測試由 GitHub Actions 在 Windows runner 上自動執行

repo 中的 PowerShell 腳本測試（`tests/*.Tests.ps1`）SHALL 由 GitHub Actions workflow 在 `windows-latest` runner 上以 Pester 5 執行。測試失敗 SHALL 使 workflow 失敗。

Workflow SHALL 在針對 `main` 的 pull request 時觸發，且 SHALL 以 `paths` filter 限定於「測試本身」與「被測腳本所在目錄」的變動，避免與測試無關的 dotfile 變更觸發 Windows runner。

Workflow MUST NOT 掛在 `push` to `main` 上。純檢查型 workflow 的既有慣例（`validate-externals.yml`）是 PR-only；掛 `push` 的皆為發佈 artifact 的 workflow。所有變更均經 PR 進入 `main`，PR 已驗過的 commit 在 main 重跑不產生新資訊。

#### Scenario: 測試檔變更時觸發

- **WHEN** 開啟針對 `main` 的 pull request，其中含 `tests/` 下的變更
- **THEN** Pester workflow 觸發，在 `windows-latest` 上執行 `tests/` 內所有 `*.Tests.ps1`

#### Scenario: 被測腳本變更時觸發

- **WHEN** 開啟針對 `main` 的 pull request，其中含 `home/dot_local/bin/` 下的變更
- **THEN** Pester workflow 觸發

#### Scenario: 無關變更不觸發

- **WHEN** pull request 只含 `docs/`、`openspec/` 或 `home/` 其他子目錄的變更
- **THEN** Pester workflow 不觸發

#### Scenario: 測試失敗使 workflow 失敗

- **WHEN** 任一 Pester 測試 assertion 失敗
- **THEN** workflow step 以非零 exit code 結束，CI 顯示失敗

#### Scenario: 測試相對路徑假設成立

- **WHEN** Pester 測試以 `Split-Path -Parent $PSScriptRoot` 推導 repo root 並定位被測腳本
- **THEN** 該推導成立，亦即 `tests/` SHALL 維持在 repo root 的下一層，不得再下沉一層目錄
