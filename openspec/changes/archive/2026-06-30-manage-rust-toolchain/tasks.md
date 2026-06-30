## 1. 當前電腦測試（先驗證手動指令可行）

- [x] 1.1 在當前電腦執行 `rustup update stable`，確認能成功更新到 ≥ 1.95.0 並解除 cargo-binstall 編譯問題

## 2. 撰寫跨平台更新腳本

- [x] 2.1 新增 `home/run_update-rust-toolchain.sh.tmpl`：偵測 `command -v rustup`，存在則 `rustup update stable`（容錯不中斷），不存在則印訊息跳過
- [x] 2.2 新增 `home/run_update-rust-toolchain.ps1.tmpl`：偵測 `Get-Command rustup`，存在則 `rustup update stable`（容錯不中斷），不存在則印訊息跳過
- [x] 2.3 對齊 `run_update-claude-plugins.{ps1,sh}.tmpl` 的標頭/風格/OS guard 慣例

## 3. 驗證

- [x] 3.1 `chezmoi execute-template` 或 `chezmoi apply --dry-run`（兩平台可行範圍內）確認腳本 render 正常、無語法錯
- [x] 3.2 確認連續兩次 apply 都會執行（純 run_ 行為），且無 rustup 機器會跳過

## 4. 文件

- [x] 4.1 在 `README.md` 工具鏈/更新策略段落記錄：Rust 由 apply 自動追蹤 stable
