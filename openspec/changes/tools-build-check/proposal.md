## Why

`tools/statusline/`（Go）與 `tools/passgen/`（Rust）是 repo 內唯二的可編譯原始碼，但**在 PR 階段沒有任何 CI 碰過它們**。兩支 `Release *` workflow 的 trigger 都是 `push` 到 `main`，因此編譯錯誤只有在 merge 之後才會被發現——那時 main 已經是紅的，且 release artifact 沒有產出。

這不是理論風險。`tools/statusline/` 用 build tag 做平台分流：

```
$ GOOS=linux   go list -f '{{.GoFiles}}' .   → [count_unix.go statusline.go]
$ GOOS=windows go list -f '{{.GoFiles}}' .   → [count_windows.go statusline.go]
```

`count_windows.go`（81 行，依賴 `golang.org/x/sys`）在 Linux 上根本不會被編譯。任何只在單一平台跑的檢查都看不到它，而 release workflow 卻要編出四個平台的二進位。

## What Changes

- 新增 `.github/workflows/test-tools-build.yml`，在 PR 階段編譯 `tools/` 下的兩支程式，`paths` 限定於 `tools/**` 與 workflow 自身。
- Go 端 SHALL 跨編譯 `release-statusline.yml` 所產出的**全部四個** GOOS/GOARCH 組合，而非只編當前平台——否則 `count_windows.go` 的錯誤會漏網。
- Rust 端跑 `cargo test`：`tools/passgen/src/main.rs` 已有 6 個 `#[test]`，同樣從未被任何 CI 執行過。`cargo test` 涵蓋編譯，比 `cargo check` 多擋一層而成本相近。
- 與 `test-pester.yml` 一致採 PR-only：這是檢查而非發佈。

無 **BREAKING**。這是純新增的檢查，不改動任何既有 workflow、原始碼或部署行為。

## Capabilities

### New Capabilities
- `tools-build-check`: PR 階段對 `tools/` 下可編譯原始碼的建置驗證契約——觸發條件、必須涵蓋的平台矩陣、失敗即紅。

### Modified Capabilities
無。既有的 `statusline-release` 描述的是 merge 後的發佈行為，不受影響；本 change 新增的是它之前的一道閘門。

## Impact

| 類別 | 影響 |
|---|---|
| CI | 新增一支 workflow；PR 觸及 `tools/**` 時多一個 job |
| 原始碼 | 無變動 |
| 部署 | 無影響（此 workflow 不產出 artifact、不發 release） |
| spec | 新增 `tools-build-check` 一支 |

已知不涵蓋：Rust 端只在 ubuntu 執行，不跨編譯 `release-passgen.yml` 的四個 target。Rust 跨編譯需額外 `rustup target add` 與 linker 設定，而 `tools/passgen/src/main.rs` 內唯一的 `cfg` 是 `#[cfg(test)]`——沒有任何平台條件編譯，單平台檢查已涵蓋其全部程式碼。此取捨記於 design.md。

`tools/statusline/` 無 Go 測試，故 Go 端只做 build + vet，不新增測試（撰寫 statusline 測試不在本 change 範圍）。
