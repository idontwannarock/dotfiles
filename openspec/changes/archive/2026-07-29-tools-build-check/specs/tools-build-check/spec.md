## ADDED Requirements

### Requirement: tools/ 下的可編譯原始碼 SHALL 在 PR 階段被建置驗證

`tools/` 之下由 CI 編譯發佈的原始碼（`tools/statusline/` 的 Go、`tools/passgen/` 的 Rust）SHALL 由一支 GitHub Actions workflow 在 pull request 階段建置驗證。建置或測試失敗 SHALL 使 workflow 失敗。

此 workflow SHALL 在針對 `main` 的 pull request 時觸發，並以 `paths` filter 限定於 `tools/**` 與 workflow 自身。與 `pester-test-ci` 同理，此為純檢查型 workflow，MUST NOT 掛在 `push` to `main` 上——`release-*` workflow 已在 merge 後編譯。

此 workflow MUST NOT 產出 artifact 或發佈 release；那是 `statusline-release` 與 `release-passgen` 的職責。

#### Scenario: 觸及 tools/ 的 PR 觸發建置檢查

- **WHEN** 開啟針對 `main` 的 pull request，其中含 `tools/` 下的變更
- **THEN** 建置檢查 workflow 觸發

#### Scenario: 未觸及 tools/ 的 PR 不觸發

- **WHEN** pull request 只含 `home/`、`docs/`、`tests/` 或 `openspec/` 的變更
- **THEN** 建置檢查 workflow 不觸發

#### Scenario: 編譯失敗使 workflow 失敗

- **WHEN** `tools/statusline/` 或 `tools/passgen/` 存在編譯錯誤
- **THEN** 對應 job 以非零 exit code 結束，PR 顯示失敗

#### Scenario: 不產出發佈物

- **WHEN** 建置檢查 workflow 執行完成
- **THEN** 未上傳任何 artifact、未建立或更新任何 GitHub Release

### Requirement: Go 端 SHALL 涵蓋 release 產出的全部平台組合

statusline 的建置驗證 SHALL 對 `statusline-release` 所產出的每一個 `GOOS`/`GOARCH` 組合各建置一次，而非僅建置 runner 的原生平台。

此要求源自實測事實：`tools/statusline/` 以 build tag 分流平台，`GOOS=linux` 時套件檔案為 `[count_unix.go statusline.go]`，`GOOS=windows` 時為 `[count_windows.go statusline.go]`。單一平台的建置看不到另一平台的檔案，會讓該檔案的編譯錯誤一路漏到 merge 後的 release 階段才爆發。

#### Scenario: 四個平台組合皆被建置

- **WHEN** 建置檢查 workflow 執行 Go job
- **THEN** linux/amd64、darwin/amd64、darwin/arm64、windows/amd64 四組各完成一次建置

#### Scenario: 僅 Windows 可見的檔案有錯誤時被攔截

- **WHEN** `count_windows.go` 存在編譯錯誤，而 `count_unix.go` 正常
- **THEN** windows/amd64 的建置失敗，workflow 變紅（不因 linux 建置成功而放行）

### Requirement: Rust 端 SHALL 執行既有測試

passgen 的驗證 SHALL 以 `cargo test` 執行，而非僅做型別檢查——`tools/passgen/` 內含 `#[cfg(test)]` 測試模組，`cargo test` 同時涵蓋編譯與這些測試。

Rust 端 SHALL 僅在單一 host 平台執行，不跨編譯 `release-passgen` 的四個 target。此豁免的成立條件是 **passgen 原始碼不含平台條件編譯**（唯一的 `cfg` 為 `#[cfg(test)]`）；若日後加入 `#[cfg(target_os = ...)]` 之類的分流，此豁免即失效，SHALL 比照 Go 端補上跨平台建置。

#### Scenario: 既有測試被執行

- **WHEN** 建置檢查 workflow 執行 Rust job
- **THEN** `tools/passgen/` 的 `#[test]` 全數執行，任一失敗即讓 job 失敗

#### Scenario: 單平台執行

- **WHEN** 建置檢查 workflow 執行 Rust job
- **THEN** 僅於 runner 的 host target 執行，不進行 `rustup target add` 跨編譯
