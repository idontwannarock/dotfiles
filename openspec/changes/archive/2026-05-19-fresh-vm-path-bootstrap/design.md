## Context

Wave 1 把 jq、starship、zellij、uv、ripgrep 從 scoop 遷到 `.chezmoiexternal.toml`，但測試只在「現有機器」上跑。code-reviewer 在 commit `dff10c8` review 時指出潛在 fresh-VM 問題，當時暫存為 `project_chezmoi_fresh_vm_path_bootstrap.md` memory。本 change 解決該問題。

關鍵 chezmoi apply 順序（[官方文件](https://www.chezmoi.io/reference/application-order/)）：

1. Read source + destination state
2. Compute target state
3. Run `run_before_` scripts (alphabetical)
4. **Update entries**（alphabetical by target name）—— 包含 modify_ files、externals、symlinks
5. Run `run_after_` scripts

在 step 4 內部，`.claude/settings.json`（target 字母順序起頭 `.c`）會在 `.local/bin/jq.exe`（`.l`）**之前**處理。所以：

| 階段 | Fresh VM | 既有機器 |
|------|---------|----------|
| step 3 (run_before_) | jq.exe 還沒下載；setup-paths 必須補 | jq.exe 已存在；setup-paths no-op |
| step 4 (modify_settings) | bash 需要找到 jq.exe | PATH 已含 ~/.local/bin，bash 找得到 |
| step 4 (external jq.exe) | 此時才下載（太晚） | 既已存在，refresh 為 idempotent |

## Goals / Non-Goals

**Goals**:
- Fresh Windows VM 跑 `chezmoi init <repo> && chezmoi apply` 一次成功，不需要使用者預先手動加 PATH
- 既有機器（PATH 已對、jq.exe 已存在）無 regression
- 修法可重用：將來 Wave 2+ 加更多 chezmoi-external CLI 工具被 modify_*.sh 引用時，這層 PATH 注入仍會生效（避免每個工具都重補一遍）

**Non-Goals**:
- Linux/macOS 行為調整（這兩個平台 `~/.local/bin` 通常已在 PATH，無此 bug）
- 既有機器自動補 scriptEnv（`~/.config/chezmoi/chezmoi.toml` 只在 `chezmoi init` 時 render，不自動更新；需 self-heal 是另一個 change 的範圍）
- Wave 2 CLI tool migration

## Decisions

### D1: 用 `[scriptEnv]` 做 PATH 注入，而不是改 modify scripts 用絕對路徑

**選 A**: `.chezmoi.toml.tmpl` 加 `[scriptEnv]`，將 `~/.local/bin` prepend 到 PATH。
**選 B**: 改 `modify_settings.json.sh.tmpl` 把 `jq` 改成 `~/.local/bin/jq.exe` 絕對路徑。

選 A，因為：
- A 是「設一次，所有 modify_ 共用」；B 是每寫一個新 modify_ 都要記得用絕對路徑
- A 的成本是 chezmoi.toml 多 3 行；B 的成本是 modify scripts 變難讀且容易漏
- scriptEnv 是 chezmoi 官方支援的機制（[文件](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions)），不是 hack
- A 對 Wave 2+ 自然生效，B 對每個新工具都要重做

**Alternative considered**: 同時做 A+B（雙保險）。Reject 因增複雜度且 B 在 A 已生效時是死碼。

### D2: setup-paths 直接 `Invoke-WebRequest` 下載 jq，不依賴 external

External 在 step 4（與 modify_ 同階段），fresh VM 上 modify_settings.json 跑時 external 還沒輪到。所以 `run_onchange_before_setup-paths.ps1.tmpl` 必須在 step 3 親自把 jq.exe 落地。

URL 與版本與 `.chezmoiexternal.toml` 對齊（都從 GitHub Release `jqlang/jq` 抓 `jq-windows-amd64.exe`）；後續 chezmoi 進到 step 4 時，external entry 看到檔案已存在且 hash 一致就 skip 重下。版本 pin 在 `.chezmoiexternal.toml` 是 source of truth，setup-paths 用 hardcoded version 字串對齊（archive 時要驗證一致）。

**Alternative considered**:
- 讓 setup-paths 解析 `.chezmoiexternal.toml` 取 URL ＋ version：太複雜，jq 一個檔案不值
- 把 jq.exe 內嵌成 base64 dump 進 .ps1：違反 lean-as-possible 原則，更新麻煩

### D3: setup-paths 也順手寫 User PATH（持久化）

雖然 scriptEnv 已涵蓋 chezmoi-spawned scripts，但使用者打開 PowerShell 想直接用 jq 時還是需要 User PATH 有 `~/.local/bin`。setup-paths 順便做這件事（與 `run_once_after_migrate-scoop-to-external.ps1.tmpl` 的 PATH 重排序不衝突——migrate 是排序，setup-paths 是「有沒有」）。

冪等：若已存在則 no-op。

### D4: 用 `run_onchange_before_` 而非 `run_once_before_`

- `run_onchange_`: 內容變化時重跑 → 邏輯演進時自動重執行，安全網
- `run_once_`: 一旦 hash 命中就不再跑 → 若使用者後來刪了 ~/.local/bin/jq.exe，setup-paths 不會自動補

腳本本身是 idempotent，所以 `run_onchange_` 沒有副作用，反而比較安全。檔名沿用既有的 untracked stub `run_onchange_before_setup-paths.ps1.tmpl`。

## Risks / Trade-offs

**[既有機器 chezmoi.toml 不會自動補 scriptEnv]** → 暫不處理。Mitigation：既有機器的 User PATH 已對，沒有 scriptEnv 也照常工作。若哪天有人反映「我把 ~/.local/bin 從 User PATH 移掉了，現在 modify_ 找不到 jq」，再開另一個 change 擴充 `patch-chezmoi-config.ps1.tmpl` 做 self-heal。

**[scriptEnv 把 PATH 覆寫掉的風險]** → scriptEnv 寫的是「prepend ~/.local/bin 到 chezmoi 啟動時看到的 PATH」，用 `{{ env "PATH" }}` 在 init 時 render。理論上若使用者跑 chezmoi 時 shell 的 PATH 是個破值（例如 cron 環境變數很少），那 scriptEnv render 出的 PATH 也短。Mitigation：fresh VM 上 init 時的 PATH 至少包含 System32 等基本目錄，足夠 chezmoi 工作。

**[jq.exe 下載 URL 與 .chezmoiexternal.toml 版本不一致]** → Mitigation：tasks.md 註記 archive 時要 cross-check 兩處版本字串。長期可考慮把版本字串集中到 `.chezmoi.toml.tmpl` 的 `[data]` 共享，但本 change 不擴大範圍。

**[chezmoi 在 step 3 找不到 PowerShell]** → 不會。PowerShell 是 Windows 內建（Windows PowerShell 5.1 + 隨 system 走），chezmoi 用 `[interpreters.ps1]` 預設找 `pwsh` fallback `powershell`，兩者其一必然存在。

## Migration Plan

1. Implement two file changes（一次性 PR）
2. 在當前機器 `chezmoi apply` 確認 no regression（jq 仍能 patch settings.json、existing PATH 不被破壞）
3. Squash merge
4. Fresh VM 驗證：等下一次有重灌機會時，把 `chezmoi init + apply` 走過一次。若失敗則用本 change 為 baseline 開 follow-up。
