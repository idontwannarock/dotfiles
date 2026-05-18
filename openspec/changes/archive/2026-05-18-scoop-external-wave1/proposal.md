## Why

Scoop 在 SSH（Tailscale → Windows host）session 下會踩 shim + `current` junction 解析雷,
已多次造成 starship、zellij 無法啟動（commits `9ba940b`、`1fe9d55`),
目前靠 `Documents/exact__shared-profile.d/35-scoop-ssh-shims.ps1` + `90-prompt.ps1` 做 PATH 重寫繞過,
但每加一個工具就要再補一個 hook,維護成本與 SSH session 啟動延遲都在累積。
單檔 CLI binary 改走 `.chezmoiexternal.toml` 直接放 `~/.local/bin/`(現已用於 `statusline.exe`、`passgen.exe`、`rtk.exe`),
完全沒 shim、SSH session 下零摩擦,也讓 chezmoi 真正成為這些工具的 source of truth。

## What Changes

**新增 chezmoi-external entries（5 個工具）:**
- `starship.exe` ← GitHub Release: `starship/starship`
- `zellij.exe` ← GitHub Release: `zellij-org/zellij`
- `uv.exe` ← GitHub Release: `astral-sh/uv`
- `jq.exe` ← GitHub Release: `jqlang/jq`
- `rg.exe`(ripgrep) ← GitHub Release: `BurntSushi/ripgrep`

dos2unix 因無乾淨的 GitHub release 來源(SourceForge URL 不穩定),Wave 1 不處理,
繼續由 scoop 管理。

**清理 scoop 安裝呼叫:**
- `run_once_install-01-runtimes.ps1.tmpl`: 移除 `Install-ScoopPackage "starship"`、`Install-ScoopPackage "uv"`
- `run_onchange_before_install-prereqs.ps1.tmpl`: 移除 `Ensure-ScoopTool "jq"`(`dos2unix` 仍保留)
- zellij、ripgrep 之前不在任何 install script,新機自然不會經 scoop 裝

**Active migration on existing machines:**
新增 `run_once_after_migrate-scoop-to-external.ps1.tmpl`:
- `scoop uninstall starship zellij uv jq ripgrep`(若已存在)
- 修改 User PATH,將 `~/.local/bin` 移到 `~/scoop/shims` 之前
- 一次性執行(run_once_after_ 確保在 `.chezmoiexternal.toml` 下載完成後執行)

**清理 SSH workaround:**
- `Documents/exact__shared-profile.d/35-scoop-ssh-shims.ps1`: 移除 zellij 分支;若整支為空則刪除
- `Documents/exact__shared-profile.d/90-prompt.ps1`: 移除 starship 的 shim 重寫邏輯,改為標準 `starship init powershell` 一行

**不動:**
- `/scoop/scoopfile.json`(本來就不受 chezmoi 管理,純 backup snapshot)
- dos2unix 的 scoop 安裝(Wave 1 範圍外)

**Breaking changes:**
- 既有 Windows 機器執行 `chezmoi apply` 後,5 個工具會從 scoop 卸載並改由 `~/.local/bin/` 提供。如使用者依賴 scoop 的版本特性(如 manifest hooks、shims 自動補環境變數),需重新評估。所有 5 個都是純 CLI binary,目前沒這類依賴。

## Capabilities

### New Capabilities
(無)

### Modified Capabilities
- `tool-dependencies`: 既有 "Starship 安裝腳本支援 macOS 與 Linux" requirement 修改 — Windows 不再走 Scoop,改由 `.chezmoiexternal.toml` 下載 GitHub Release 至 `~/.local/bin/starship.exe`;同時新增 4 條 requirement 涵蓋 zellij/uv/jq/ripgrep 在 Windows 上的 chezmoi-external 行為;新增 1 條 requirement 涵蓋 PATH ordering 與 scoop migration 的一次性遷移腳本。

## Impact

**Code changes:**
- `.chezmoiexternal.toml`: 新增 5 條 entries(各含 Windows 專屬下載 URL 與 archive 抽檔規則)
- `run_once_install-01-runtimes.ps1.tmpl`: 移除 2 行 scoop install 呼叫
- `run_onchange_before_install-prereqs.ps1.tmpl`: 移除 1 行 scoop install 呼叫
- `run_once_after_migrate-scoop-to-external.ps1.tmpl`(新檔): scoop uninstall + PATH reorder
- `Documents/exact__shared-profile.d/35-scoop-ssh-shims.ps1`: 移除 zellij 段(若整支為空則刪除)
- `Documents/exact__shared-profile.d/90-prompt.ps1`: 簡化 starship 啟動為標準呼叫

**Existing machine state changes:**
- scoop 卸載 5 個套件
- User PATH 順序變更

**Memory updates(在 archive step 處理):**
- `MEMORY.md` 中 "Win32-OpenSSH × Scoop SSH gotchas" 條目更新 scope(starship/zellij 已遷)
- 新增/更新 reference 條目: "chezmoi-external CLI 工具清單"

**Out of scope(Wave 2/3 / 永不):**
- bun、gh、lazydocker、pwsh、fastfetch、onefetch 等 CLI 漏網之魚 → Wave 2
- GUI app declarative install → Wave 3
- dos2unix → 等找到乾淨 release 源再處理
- JDK / Python / Rust toolchain 遷移 → 不打算遷
