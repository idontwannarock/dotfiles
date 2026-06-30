## Context

Rust 的安裝由既有 bootstrap 負責（Unix: `run_once_install-01-runtimes.sh.tmpl` 用官方 rustup installer；Windows: `run_once_after_migrate-scoop-wave10-toolchain.ps1.tmpl` 用 rustup-init），兩者都把 toolchain 放在預設位置（`~/.cargo` + `~/.rustup`），且都以 `run_once_` 執行 → 每台機器只跑一次，之後不再更新。

本 repo 其它工具鏈用「pin 版本 + Renovate 註解」管理（go/maven/nvm/temurin），但使用者明確選擇 Rust 走「追蹤 stable、apply 時自動更新」而非 pin 明確版本。需要一個會在每次 apply 重跑的機制。

## Goals / Non-Goals

**Goals:**
- 每次 `chezmoi apply` 確保 stable toolchain 更新到最新（`rustup update stable`）。
- 跨平台（Windows PowerShell + Unix sh）。
- 對沒有 rustup 的機器無害（偵測不到就跳過，不讓 apply 失敗）。
- 風格對齊既有 `run_update-claude-plugins.{ps1,sh}.tmpl`。

**Non-Goals:**
- 不負責「安裝」rust（仍由既有 bootstrap 負責）。
- 不 pin 明確版本、不加 Renovate 註解（使用者選擇追蹤 stable）。
- 不引入 `rust-toolchain.toml`（那是 per-project，非全域）。
- 不改變 `~/.cargo` / `~/.rustup` 位置或 PATH 佈線。

## Decisions

### D1: 用純 `run_` 而非 `run_once_` / `run_onchange_`
- **選擇**：檔名 `run_update-rust-toolchain.{ps1,sh}.tmpl`（無 `once`/`onchange` 前綴）。
- **理由**：`run_once_` 每台機器只跑一次（=現況的破口）；`run_onchange_` 只在腳本內容雜湊改變時重跑，靜態的 `rustup update stable` 內容永不變 → 也只會跑一次。要「每次 apply 都追蹤 stable」唯一正確的 primitive 是純 `run_`（每次 apply 執行）。
- **先例**：`run_update-claude-plugins.{ps1,sh}.tmpl` 正是同一範式（每次 apply 更新 plugins）。

### D2: 偵測 rustup 才執行，否則 no-op
- **選擇**：腳本開頭檢查 `rustup` 是否存在（PowerShell `Get-Command rustup`；sh `command -v rustup`），不存在就印訊息並 exit 0。
- **理由**：安裝是 bootstrap 的責任；本腳本只負責「保持最新」。在尚未或刻意不裝 rust 的機器上必須無害，不可讓整個 apply 失敗。

### D3: 只更新 stable，不動 default 或其它 toolchain
- **選擇**：執行 `rustup update stable`。不呼叫 `rustup default`（bootstrap 已設 default stable）。
- **理由**：最小變更。使用者要的是「stable 保持最新」，default 由 bootstrap 一次性設定即足夠。

### D4: 容錯但可見
- **選擇**：`rustup update stable` 失敗（如離線）時印 warning 但不讓 apply 整體失敗。
- **理由**：版本更新是「best-effort 維護」，網路不通不該擋住其它設定部署——對齊既有 update 腳本的容錯態度。

## Risks / Trade-offs

- [每次 apply 多一次網路檢查/下載] → rustup 在已是最新時很快返回；與既有 `run_update-claude-plugins` 同等成本，可接受。
- [追蹤 stable 不可重現] → 使用者已知並接受；若日後要可重現再切換成 pin 版本 + Renovate（已在選項中評估過）。
- [離線環境 apply 出現 warning] → 可接受，腳本不因此失敗。

## Migration Plan

- 純新增檔案，無破壞性。首次 apply 後 stable 會被更新到最新；既有 bootstrap 不受影響。
- Rollback：刪除兩個 `run_update-rust-toolchain.*` 檔即可恢復原狀。

## Open Questions

無。
