## Context

`tools/` 下的兩支程式目前只在 merge 之後才被編譯：

| Workflow | Trigger | 何時發現編譯錯誤 |
|---|---|---|
| `release-statusline.yml` | `push` → `main`，`paths: tools/statusline/**` | merge 之後 |
| `release-passgen.yml` | `push` → `main`，`paths: tools/passgen/**` | merge 之後 |

PR 階段唯二會跑的 workflow 是 `validate-externals.yml`（驗 `.chezmoiexternal.toml` 的下載 URL）與 `test-pester.yml`（驗 `tests/` 下的 PowerShell）。兩者都不碰 `tools/`。

實測確認的關鍵事實——`tools/statusline/` 以 build tag 分流平台：

```
$ GOOS=linux   go list -f '{{.GoFiles}}' .   → [count_unix.go statusline.go]
$ GOOS=windows go list -f '{{.GoFiles}}' .   → [count_windows.go statusline.go]
```

`count_windows.go` 有 81 行、依賴 `golang.org/x/sys`，在 Linux 上完全不參與編譯。

## Goals / Non-Goals

**Goals:**

- `tools/` 下的編譯錯誤在 PR 階段就變紅，而不是 merge 後打爆 main。
- 涵蓋 `release-statusline.yml` 實際產出的全部四個平台組合，特別是只有 `GOOS=windows` 才看得到的 `count_windows.go`。
- 讓 `tools/passgen/` 既有的 6 個 `#[test]` 開始被執行。

**Non-Goals:**

- 不為 `tools/statusline/` 撰寫 Go 測試（它目前一個都沒有；補測試是獨立的工作）。
- 不產出任何 artifact、不發 release——那是 `release-*` workflow 的職責，本 workflow 純檢查。
- 不改動兩支 release workflow。
- 不做 Rust 跨編譯（見 D3）。
- 不加 `clippy`、`gofmt`、`rustfmt` 等風格檢查（本 change 的目的是「編得過」，風格是另一件事）。

## Decisions

### D1：Go 端跨編譯四個目標，而非只編當前平台

**選擇**：以 matrix 跑 `release-statusline.yml` 的同四組 `GOOS`/`GOARCH`（linux/amd64、darwin/amd64、darwin/arm64、windows/amd64），每組 `go build -o /dev/null .`。

**理由**：這是本 change 存在的主要理由。單平台檢查看不到 `count_windows.go`，而那正是最可能在 release 階段炸掉、卻在 PR 階段沉默的檔案。跨編譯純 Go（`CGO_ENABLED=0`）在單一 ubuntu runner 上即可完成，無須四個 runner。

**替代方案**：`go vet ./...` 搭配 `GOOS` 迴圈——`vet` 確實也會做型別檢查，但 `build` 才是 release 實際執行的動作，用同一個動詞比較不會有落差。兩者都做，成本可忽略。

### D2：Rust 端用 `cargo test` 而非 `cargo check`

**選擇**：`cargo test --manifest-path tools/passgen/Cargo.toml`。

**理由**：`tools/passgen/src/main.rs:185` 起有一個 `#[cfg(test)] mod tests`，內含 6 個 `#[test]`，從未被任何 CI 執行。`cargo test` 必然涵蓋編譯，所以它是 `cargo check` 的嚴格超集，而 runner 時間差異在這個規模下無意義。

**替代方案**：`cargo check` 較快但只驗型別，會把現成的測試繼續晾著。否決。

### D3：Rust 不跨編譯

**選擇**：只在 `ubuntu-latest` 的 host target 上跑。

**理由**：`grep -nE 'cfg\(|#\[cfg' tools/passgen/src/main.rs` 只有一筆，且是 `#[cfg(test)]`——原始碼內沒有任何平台條件編譯，因此單平台已涵蓋全部程式碼路徑。跨編譯到 `x86_64-pc-windows-msvc` 需要 `rustup target add` 加上 MSVC linker，成本與它能擋下的錯誤不成比例。

**風險自覺**：這個判斷綁在「passgen 沒有平台分流」這個事實上。若日後 passgen 加入 `#[cfg(target_os = ...)]`，此決策就失效，需回頭補跨編譯。已寫入 spec 的 requirement 敘述作為提醒。

### D4：PR-only，與 `test-pester.yml` 一致

**選擇**：`on: pull_request: branches: [main]`，`paths` 限定 `tools/**` 與 workflow 自身。不掛 `push`。

**理由**：沿用上一個 change 已確立的分界——發佈 artifact 的 workflow 掛 `push`，純檢查掛 `pull_request`。`release-*` 已經在 merge 後編譯一次，本 workflow 若也掛 `push` 就是同一件事做兩遍。

### D5：單一 workflow 檔、兩個獨立 job

**選擇**：`test-tools-build.yml` 內含 `go` 與 `rust` 兩個平行 job，不互為 `needs`。

**理由**：兩者無依賴關係，平行跑縮短 wall clock；同一個檔案讓「tools/ 的建置檢查」只有一個入口，不必為兩支程式各開一檔。`paths` 用 `tools/**` 涵蓋兩者——某一邊沒改動時該 job 仍會跑，但成本是秒級，不值得為此拆成兩支各自 path-filter 的 workflow。

## Risks / Trade-offs

| 風險 | 緩解 |
|---|---|
| `paths: tools/**` 使得只改 passgen 的 PR 也跑 Go job（反之亦然） | 兩個 job 都是秒級，且 Go 跨編譯無須下載額外 toolchain。刻意接受，換取設定簡單 |
| Go module cache 未設，每次 PR 重新下載 `golang.org/x/sys` | `actions/setup-go@v5` 預設已啟用 module cache，無須額外設定 |
| D3 的判斷會隨 passgen 演進而失效 | 判斷依據（無平台條件編譯）明寫進 spec requirement，日後加 `cfg(target_os)` 時能被看見 |
| 新增 required check 可能讓既有 PR 卡住 | 本 workflow 不設為 required；且有 `paths` filter，不相關的 PR 根本不會啟動它 |

## Migration Plan

無。純新增 workflow，不改既有行為。Rollback 即刪除該檔。

## Open Questions

無。
