## 1. 新增 workflow

- [x] 1.1 建立 `.github/workflows/test-tools-build.yml`：`on: pull_request: branches: [main]`，`paths` 限定 `tools/**` 與 workflow 自身；不掛 `push`
- [x] 1.2 `go` job：`actions/setup-go@v5`，以 matrix 跑 linux/amd64、darwin/amd64、darwin/arm64、windows/amd64 四組，每組 `CGO_ENABLED=0 go build -o /dev/null .` 並加 `go vet ./...`（同樣帶 `GOOS`/`GOARCH`）
- [x] 1.3 `rust` job：`ubuntu-latest`，`cargo test --manifest-path tools/passgen/Cargo.toml`，不做跨編譯
- [x] 1.4 兩個 job 平行，不設 `needs`；workflow 不上傳 artifact、不發 release
- [x] 1.5 YAML 解析與 trigger 形狀驗證（`python3 -c "import yaml; ..."`）

## 2. 本機先驗（在推 CI 之前）

- [x] 2.1 本機重現 Go matrix：四組 `GOOS`/`GOARCH` 各跑一次 build + vet，確認全綠
- [x] 2.2 確認 `count_windows.go` 確實只在 `GOOS=windows` 進入編譯（`go list -f '{{.GoFiles}}'` 對照）
- [x] 2.3 Rust 端本機無 cargo，明確標示為只能由 CI 驗證，不得假裝驗過（**尚未驗**：等 PR CI）

## 3. 負向驗證（證明檢查真的會擋）

- [x] 3.1 **已實測**：暫時在 `count_windows.go` 注入一個編譯錯誤，確認**只有** windows/amd64 那組變紅、linux 那組仍綠——實測結果 linux/darwin 皆 GREEN、windows/amd64 RED（`count_windows.go:83:41: cannot use "not an int" ... as int value`），證明 matrix 確實擋下單平台檢查會漏掉的錯誤
- [x] 3.2 還原注入的錯誤，確認回到全綠

## 4. 收尾

- [x] 4.1 `openspec validate tools-build-check` 通過
- [x] 4.2 README 的 `.github/workflows/` 說明補上此檢查
- [ ] 4.3 `verify-done`：列出實際執行的命令與輸出，未驗項目明確標示
