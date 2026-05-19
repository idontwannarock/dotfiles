## Why

Wave 1（`2026-05-18-scoop-external-wave1`）把 jq 從 scoop 遷到 `.chezmoiexternal.toml` 後，「後續 chezmoi 腳本仍能呼叫 jq」這條 scenario 在使用者**現有機器**通過——但只是因為 User PATH 早就手動加過 `~/.local/bin`、且 `~/.local/bin/jq.exe` 早就存在。在**全新 Windows VM** 上跑 `chezmoi init <repo> && chezmoi apply` 會失敗，因為：

1. chezmoi 的 apply 順序是 (1) compute → (2) `run_before_` → (3) **update entries (alphabetical, modify_ 與 externals 同階段)** → (4) `run_after_`
2. `.claude/settings.json`（modify）在字母順序上**早於** `.local/bin/jq.exe`（external），所以第一次 apply 時 `modify_settings.json.sh.tmpl` 跑時 `jq.exe` 物理上還沒下載；且 chezmoi spawn 的 bash 子程序也沒有 `~/.local/bin` 在 PATH 中。
3. `run_once_after_migrate-scoop-to-external.ps1.tmpl` 在 step 4 才修 User PATH，太晚。

修這個 bug 才能讓重灌或新同事真的可以 `chezmoi init + apply` 一氣呵成。Wave 2+ 加更多 external CLI 工具被 modify_ 引用時，同樣的雷會再炸。

## What Changes

**新增 `[scriptEnv]` 設定（一行 PATH 注入）**:
- `.chezmoi.toml.tmpl` 新增 `[scriptEnv]` 區塊，將 `~/.local/bin` prepend 到所有 chezmoi-spawned scripts（含 modify_ 經 `[interpreters.sh]` 啟動的 bash）的 PATH。Fresh VM 上 `chezmoi init` 渲染時就會寫入 `~/.config/chezmoi/chezmoi.toml`，第一次 apply 就生效。

**填實 `run_onchange_before_setup-paths.ps1.tmpl` stub**:
- 該檔目前是 untracked stub（只寫 `test`）。改寫為 Windows-only 腳本，職責：
  - 確保 `~/.local/bin` 目錄存在
  - 若 `~/.local/bin/jq.exe` 不存在 → `Invoke-WebRequest` 從 GitHub Release（與 `.chezmoiexternal.toml` 同一 URL 與 pinned version）直接下載一份
  - 確保 User PATH 包含 `~/.local/bin`（持久化，給未來的 shell session）
- 為什麼不靠 external：external 在 step 3（與 modify_ 同階段，但 alphabetical 晚於 `.claude/`）才下載，根本還沒輪到時 modify_settings.json 就已經跑掉了。

**不破壞**:
- `run_once_after_migrate-scoop-to-external.ps1.tmpl`（scoop uninstall + PATH 重排序）—— 任務不同，繼續存在
- 現有機器：User PATH 已對、jq.exe 已存在 → 新 setup-paths 走 idempotent no-op 分支；新 scriptEnv 只是多 prepend 一次（無害）

## Capabilities

### New Capabilities
（無）

### Modified Capabilities
- `chezmoi-structure`: `.chezmoi.toml.tmpl` 新增「為所有 chezmoi-spawned scripts 注入 PATH」的 requirement，確保 modify_*.sh 在 fresh VM 第一次 apply 時就能找到 `~/.local/bin` 內的工具。
- `tool-dependencies`: 修改 Wave 1 的「jq 在 Windows 上由 chezmoi-external 安裝」requirement——新增 fresh-VM bootstrap 路徑（`run_onchange_before_setup-paths.ps1.tmpl` 確保 jq.exe 存在 + scriptEnv 確保 PATH 注入），讓 modify_settings.json 在第一次 apply 就能呼叫 jq。

## Impact

**Code changes**:
- `.chezmoi.toml.tmpl`（修改）：新增 `[scriptEnv]` 區塊（~3 行）
- `run_onchange_before_setup-paths.ps1.tmpl`（覆寫，目前是 untracked stub）：~50 行 Windows-only bootstrap 邏輯
- `openspec/specs/chezmoi-structure/spec.md`、`openspec/specs/tool-dependencies/spec.md`：對應 delta 更新

**Existing machine state changes**: 無實質變化
- `~/.config/chezmoi/chezmoi.toml` **不會**自動補 `[scriptEnv]`（chezmoi.toml 只在 `chezmoi init` 時 render）；現有機器 PATH 已對，缺 scriptEnv 不影響 modify_ 工作。
- 若使用者想讓現有機器也有 scriptEnv 安全網，可手動 `chezmoi init` 重 render，或等之後另開 change 擴充 `run_onchange_before_patch-chezmoi-config.ps1.tmpl` 做 self-heal（**out of scope**）。

**Out of scope**:
- Wave 2 CLI tool migration（另開 change）
- `run_onchange_before_patch-chezmoi-config.ps1.tmpl` 擴充為 scriptEnv self-heal
- Linux/macOS（這兩個平台 `~/.local/bin` 通常已在 PATH，沒有此 bug；scriptEnv 在這兩個平台上也會生效但不依賴它）

**Memory updates（archive step 處理）**:
- 移除 `project_chezmoi_fresh_vm_path_bootstrap.md`（問題已解，project memory 不留 stale 條目）
- 視情況補一條 reference 條目記錄「chezmoi modify_ 與 externals alphabetical ordering 的雷」
