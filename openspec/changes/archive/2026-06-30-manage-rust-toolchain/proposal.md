## Why

Rust 目前只在 `run_once_install-01-runtimes.sh.tmpl`（Unix）與 wave10 migrate 腳本（Windows）裡用官方 rustup-init 裝一次，之後就再也不會更新。結果 `rustc` 在機器上逐漸變舊（實際遇到卡在 1.94.0），導致 `cargo install`（如 cargo-binstall，需要相依套件要求的較新編譯器）失敗。其它工具鏈（go/maven/nvm…）都已被持續管理，Rust 是唯一沒有版本管理的破口。

## What Changes

- 新增跨平台 `run_update-rust-toolchain.{ps1,sh}.tmpl`，在每次 `chezmoi apply` 執行 `rustup update stable`，讓 stable toolchain 持續保持最新。
- 沿用既有 `run_update-claude-plugins.{ps1,sh}.tmpl` 的「每次 apply 都跑」純 `run_` 範式（非 `run_once_`/`run_onchange_`）。
- 冪等且容錯：偵測不到 `rustup` 時跳過（不報錯），讓尚未 bootstrap rust 的機器照常 apply。
- 在 README 對應段落記錄 Rust 版本由 apply 自動追蹤 stable。

## Capabilities

### New Capabilities
- `rust-toolchain-management`: 定義 Rust toolchain 在 chezmoi apply 期間持續追蹤並更新 stable 版本的行為（安裝由既有 bootstrap 負責，本 capability 只負責「保持最新」）。

### Modified Capabilities
<!-- 無：既有 tool-dependencies / windows-toolchain-provisioning 只規範一次性安裝，不變更其需求 -->

## Impact

- 新增檔案：`home/run_update-rust-toolchain.ps1.tmpl`、`home/run_update-rust-toolchain.sh.tmpl`
- 文件：`README.md`（工具鏈/更新策略段落）
- 行為：每次 `chezmoi apply` 會多一次 `rustup update stable` 的網路檢查（與既有 `run_update-claude-plugins` 同類成本）；無 rustup 的機器不受影響。
