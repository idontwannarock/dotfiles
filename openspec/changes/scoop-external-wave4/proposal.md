## Why

延續 Wave 1/2/3 收尾掃尾。剩餘 `Install-ScoopPackage` 呼叫中，**Category B：純清理（無需 chezmoi-external）** 的 5 個工具已驗證 dotfiles 內無人引用，且各自有更好的替代來源（OS-bundled、PowerToys 模組、純孤兒）。一次清掉縮小 scoop 依賴面積，並為 `project_dotfiles_release_mirror` 鋪路。

判斷依據已記錄於 `project_scoop_external_wave4_candidates.md`（Category B），本次再追加 grep 驗證確認真的無人用：
- `clink`：dotfiles 沒任何地方跑 `clink autorun install`，starship 已透過 PowerShell/Git Bash/zsh init
- `dark`（WiX）：grep `dark.exe`/`wixtoolset` 全 repo 無人用，掃描所有已安裝 scoop manifest 也無人宣告為 dep
- `vimtutor`：互動式教學程式，無腳本依賴
- `winget`：Win10 1809+/Win11 已 OS-bundled 在 `%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe`；scoop shim 純冗餘。`99-command-not-found.ps1` 透過 PowerToys `Microsoft.WinGet.CommandNotFound` 模組呼叫 OS-bundled winget，不依賴 scoop shim
- `winget-ps`：`Microsoft.WinGet.Client` PowerShell 模組，dotfiles 完全沒有 import 過

## What Changes

**清理 scoop 安裝呼叫**：
- `run_once_install-cli-tools.ps1.tmpl`：
  - 移除 `Install-ScoopPackage "clink"`
  - 移除 `Install-ScoopPackage "dark"`
  - 移除 vimtutor 安裝區塊（bespoke path-check）
  - 移除 `Install-ScoopPackage "winget"`
  - 移除 winget-ps 安裝區塊（bespoke path-check）
  - 留下說明註解註明各自移除原因

**Active migration on existing machines**：
新增 `run_once_after_migrate-scoop-wave4.ps1.tmpl`：
- `scoop uninstall clink` 若存在
- `scoop uninstall winget` 若存在
- `scoop uninstall winget-ps` 若存在
- **不**做 `scoop uninstall dark`：軟脫管（dotfiles 不再管理，既存安裝保留）
- **不**做 `scoop uninstall vimtutor`：軟脫管（同上）

**程式碼註解補強**：
- `Documents/PowerShell/profile.d/99-command-not-found.ps1`：新增 header comment 說明前置條件（PowerToys CommandNotFound 模組 + OS-bundled winget），不動程式邏輯

**不動**：
- `.chezmoiexternal.toml`：不新增任何條目（Category B 本質就是「不需要外部 binary」）
- 既有 Wave 1+2+3 entries、migration 腳本、PATH 設定

**Breaking changes**：
- 既有 Windows 機器執行 `chezmoi apply` 後，`clink`/`winget`/`winget-ps` 會從 scoop 卸載
  - clink：若使用者依賴 clink 提供 cmd.exe 命令列增強，需自行重裝（dotfiles 不再管理）
  - winget：自動 fallback 到 OS-bundled `winget.exe`（Win10 1809+/Win11）
  - winget-ps：dotfiles 無 import；若使用者個人 script 有 `Find-WinGetPackage` 之類 cmdlet 依賴，需自行 `Install-Module Microsoft.WinGet.Client`
- `dark`/`vimtutor`：**不會被卸載**（軟脫管），現有安裝保留，新機 bootstrap 不再裝

## Capabilities

### New Capabilities
（無）

### Modified Capabilities
- `tool-dependencies`：新增 5 條 requirement 涵蓋 clink/dark/vimtutor/winget/winget-ps 從 scoop install list 移除（含硬清/軟脫管差異）；新增 1 條涵蓋 Wave 4 一次性遷移腳本（3 個硬清項目，無 PATH 動作）；新增 1 條涵蓋 99-command-not-found.ps1 註解明示前置條件

## Impact

**Code changes**：
- `run_once_install-cli-tools.ps1.tmpl`：移除 5 個工具安裝區塊（3 行 `Install-ScoopPackage` + 2 個 bespoke path-check），補上說明註解
- `run_once_after_migrate-scoop-wave4.ps1.tmpl`（新檔）：scoop uninstall 3 個套件（clink/winget/winget-ps）
- `Documents/PowerShell/profile.d/99-command-not-found.ps1`：補 header comment

**Existing machine state changes**：
- scoop 卸載 3 個套件（clink + winget + winget-ps）
- `dark`/`vimtutor` 既有安裝保留
- User PATH **不變**（Wave 1 已搞定 ordering）
- `99-command-not-found.ps1` 行為**不變**：PowerToys 模組仍正常載入並呼叫 OS-bundled winget

**Memory updates（在 archive step 處理）**：
- `reference_chezmoi_external_cli_tools.md`：在「Wave 4 進度」處標記 Category B 完成（無新 entries）
- `project_scoop_external_wave4_candidates.md`：Category B 從候選清單劃掉
- 更新 `MEMORY.md` 索引若需

**Out of scope（後續 Wave 候選）**：
- **archive-pattern**：gpg/ffmpeg/nvm/vim（Category A，需要 `type = "archive"` 新模式）
- **docker audit**：Category C，獨立議題
- **defer**：Category D，多版本 toolchain 管理
- **永不**：Category E，7z + lens
