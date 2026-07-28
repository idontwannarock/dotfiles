## Why

`chezmoi apply` 目前的輸出無法回答「現在跑到哪、這段在做什麼、跑完了沒」。腳本裡的段落標題（`# ── Claude Code ──`）只是**註解**，不會印出來；起訖 banner 有三種並存寫法（`=== Migration complete. ===` / `=== Wave 6 migration complete. ===` / 完全沒有），還有 8 支腳本連 banner 都沒有。apply 失敗時只能靠猜是哪一段炸的。

同時 source 有大量逐字複製：7 支 `migrate-scoop-wave*` 腳本內容**完全相同**、只差 `$pkgs` 一行；`npm_install` / `Install-NpmPackage` / `apt_install` / `brew_install` 等守衛函式各自散落重寫。改一次行為要改十幾個地方，且 `chezmoi-author` skill 沒有任何條文約束這件事，所以下一支新腳本還會再複製一次。

## What Changes

- **`chezmoi-author` skill 新增兩節規範**（`.chezmoitemplates/skills/chezmoi-author.md`）：
  - *Script Logging Contract*：每支 `run_*` / `modify_*` 腳本必須印出開始 banner、每個段落的**目的**（runtime 可見，非註解）、結束 banner；早退路徑也必須印結束 banner。定義統一的 log 動詞（begin / section / step / skip / warn / end）。
  - *Shared Fragment Extraction*：同一 interpreter 內重複出現 2 次以上的邏輯，必須抽到 `.chezmoitemplates/scripts/` 並以 `{{ template }}` 引用；並說明「合併 vs 抽取」的判準（相同形狀只差資料 → 合併；獨特邏輯共用工具 → 抽取）。
  - Authoring Checklist 增加對應檢查項。

- **新增 `.chezmoitemplates/scripts/` 共用 fragment**：
  - `log.sh` / `log.ps1`：`log_begin` / `log_section` / `log_step` / `log_skip` / `log_warn` / `log_end` 六個動詞，兩個 interpreter 語意對齊。
  - `npm-install.sh` / `npm-install.ps1`：npm 全域套件的冪等安裝守衛。
  - `pkg-install.sh`：依 OS 分派 apt / brew 的冪等安裝守衛。
  - `brew-cask-install.sh`：Homebrew cask 冪等安裝守衛（macOS）。
  - `scoop-uninstall.ps1`：scoop 套件冪等移除 + orphan shim 清理。

- **合併 8 支純 scoop-uninstall 腳本為 1 支**：`migrate-scoop-wave{2,3,4,5,6,7,11,12a}` → `run_once_after_migrate-scoop-cleanup.ps1.tmpl`，以單一「套件 → 移除理由」表驅動；原本 wave 11 專有的 orphan-shim 清理提升為所有套件共用（且收斂為「只在實際 uninstall 後才清」）。

- **其餘既有腳本改寫套用新慣例**：wave 1 / 8 / 9 / 10 / 12b（保留各自獨特邏輯，改用共用 fragment）、以及約 25 支活躍的 install / update / setup / patch / register / configure 腳本。

- 不涉及行為變更：所有安裝、移除、PATH 改寫的**實際效果**維持原樣，只改 log 與程式碼組織。

## Capabilities

### New Capabilities
- `chezmoi-script-conventions`: chezmoi `run_*` / `modify_*` 腳本的撰寫契約 —— runtime log 結構（起訖 banner、段落目的、早退也要收尾）、共用邏輯抽取到 `.chezmoitemplates/scripts/` 的判準，以及 `chezmoi-author` skill 承載這些條文的義務。

### Modified Capabilities
- `tool-dependencies`: 該 spec 以 8 條獨立需求逐支點名 `run_once_after_migrate-scoop-wave{2,3,4,5,6,7,11,12a}.ps1.tmpl` 的檔名。合併後這些檔名不再存在，需收攏為單一「scoop 清理腳本」需求，並完整保留原有的每項約束（soft-unmanaged 排除清單、不動 User PATH、jdtls shim 清理、scoop 不存在時整支 skip）。

## Impact

- **`home/.chezmoitemplates/skills/chezmoi-author.md`** — 新增兩節 + checklist 項目。skill 經 name-map wrapper 同時部署到 Claude 與 Codex，改動需重新 render 兩邊 wrapper 驗證。
- **`home/.chezmoitemplates/scripts/`** — 新增 6 個 fragment（既有 `load-nvm` / `load-sdkman` / `profile-modify` 不動）。
- **`home/run_*.tmpl`** — 約 25 支改寫、8 支刪除、1 支新增。
- **`run_once_` 重跑**：chezmoi 的 `scriptState` 以腳本**內容 SHA256** 為 key，因此所有被改寫的 `run_once_` 腳本會在下次 apply 重跑一次。所有腳本都有 `command -v` / `Get-Command` 冪等守衛，重跑為 no-op，僅產生 skip 訊息。已與使用者確認接受此成本。
- **不需要 `.chezmoiremove`**：被刪除的是 `run_*` 腳本，不部署到 target，刪除 source 即結束生命週期。
- **驗證限制**：這台機器是 Linux/WSL，PowerShell 腳本無法在此實際執行；Windows 側只能做 `chezmoi execute-template` 渲染驗證，實機 apply 抽查需在 Windows 機器上補做。
