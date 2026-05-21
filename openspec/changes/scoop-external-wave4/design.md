## Context

延伸 Wave 1（`2026-05-18-scoop-external-wave1`）+ Wave 2（`2026-05-20-scoop-external-wave2`）+ Wave 3（`2026-05-20-scoop-external-wave3`）的清理 momentum。Wave 4 處理 **Category B：純清理**——剩餘 `Install-ScoopPackage` 呼叫中無需 chezmoi-external、亦無人引用的 5 個工具：`clink`、`dark`、`vimtutor`、`winget`、`winget-ps`。

Wave 4 規模刻意維持輕量：**0 個新 external entry** + 5 個 scoop install 區塊移除 + 1 個 migration script + 1 處註解補強。不引入新部署模式（archive-pattern 留給未來 Wave）。

## Goals / Non-Goals

**Goals**：
- 5 個工具從 `run_once_install-cli-tools.ps1.tmpl` 移除安裝邏輯
- 3 個工具（clink/winget/winget-ps）從既有機器 scoop 主動卸載
- 2 個工具（dark/vimtutor）軟脫管——dotfiles 不再管理，現有安裝保留
- `99-command-not-found.ps1` 補 header comment 註明前置條件，無程式變動
- 既有機器 PATH 不變、`99-command-not-found.ps1` 行為不變

**Non-Goals**：
- archive-pattern（Category A：gpg/ffmpeg/nvm/vim）→ 後續 Wave 候選
- docker audit（Category C）→ 獨立議題
- 多版本 toolchain 管理（Category D：python/jdk/go/rustup/mvn）
- 觸及 GUI app（lens）或 file-association 工具（7z）
- 自家 release mirror（supply-chain pinning）→ 所有 Wave 收尾後做
- 改寫 `99-command-not-found.ps1` 程式碼邏輯

## Decisions

### D1: 5 個工具區分「硬清」與「軟脫管」兩種處理

| 工具 | 處理方式 | 理由 |
|---|---|---|
| `clink` | 硬清（scoop uninstall） | 純孤兒，dotfiles 沒任何 init 跑 `clink autorun install`，starship 已透過 PowerShell/Git Bash/zsh init |
| `winget` | 硬清（scoop uninstall） | OS-bundled `%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe`（Win10 1809+/Win11）取代；scoop shim 純冗餘 |
| `winget-ps` | 硬清（scoop uninstall） | dotfiles 完全沒有 import `Microsoft.WinGet.Client` cmdlet；99-command-not-found.ps1 用的是另一個 PowerToys 模組（`Microsoft.WinGet.CommandNotFound`），不依賴 winget-ps |
| `dark` | 軟脫管（只刪 install） | grep 全 repo 無人用 `dark.exe`，掃描所有已安裝 scoop manifest 也無人宣告為 dep；但保留現有安裝避免破壞未驗證的人工流程 |
| `vimtutor` | 軟脫管（只刪 install） | 互動式教學程式，無腳本依賴；保留現有安裝給臨時使用 |

**Alternative considered**：5 個全硬清。Reject——`dark` 與 `vimtutor` 都驗證過真的無人用，但「軟脫管」風險更低（dotfiles 不再管理 + 現有安裝保留），且不卸載對 fresh VM bootstrap 沒影響（scoop dependency resolution 處理）。差異在「使用者既有環境是否被動到」，這次選不動。

**Alternative considered**：5 個全軟脫管。Reject——clink/winget/winget-ps 都已徹底驗證無人用，留著只是占空間。winget 特別冗餘（OS-bundled 已 cover），保留 scoop 版反而可能造成 PATH 優先序混淆。

### D2: 不新增 chezmoi-external entries

Category B 本質就是「不需要外部 binary」：
- winget：OS-bundled 已存在，不需要自己抓
- winget-ps：dotfiles 無人用，不需要安裝任何形式
- clink/dark/vimtutor：不再管理，使用者需要可手動 scoop install

**Alternative considered**：把 winget 改用 chezmoi-external 自己抓 `microsoft/winget-cli` Release。Reject——這跟 OS-bundled 形成兩條 PATH lookup 路徑，反而製造混淆。OS-bundled 是更穩定的來源（Microsoft 自己維護的 App Installer 機制），沒理由替它做另一份。

### D3: Migration script 模式延續 Wave 1+2+3

新檔 `run_once_after_migrate-scoop-wave4.ps1.tmpl`：
- 冪等：`scoop list <pkg>` 判定已安裝才 `scoop uninstall`，未安裝 no-op
- 處理 3 個工具（clink/winget/winget-ps），dark/vimtutor 跳過
- 不動 User PATH（Wave 1 已搞定 `~/.local/bin` 優先序）
- 命名沿用 `run_once_after_migrate-scoop-wave<N>.ps1.tmpl` 慣例

### D4: `99-command-not-found.ps1` 只補 comment 不動 code

現況：3 行的最小檔，`Import-Module Microsoft.WinGet.CommandNotFound -ErrorAction SilentlyContinue`。

補強：在第 1 行注釋區塊後新增 header comment 說明：
- 此檔依賴 PowerToys 提供的 `Microsoft.WinGet.CommandNotFound` 模組
- 該模組底層呼叫 `winget.exe`（OS-bundled，Win10 1809+/Win11）
- 缺任何一環只是 silent no-op（`-ErrorAction SilentlyContinue`），不影響 PowerShell 啟動

**Alternative considered**：直接刪除這個檔案（既然依賴 PowerToys 而 dotfiles 不裝 PowerToys）。Reject——PowerToys 是使用者個人偏好工具，這個 .ps1 已正常運作多年；軟脫管原則同樣適用：dotfiles 不負責安裝 PowerToys，但既然檔案存在且功能正確，留著並補說明即可。

### D5: 不動 `.chezmoiignore.tmpl`

5 個工具都不是 chezmoi-managed 檔案（它們是 scoop 安裝的 binary），ignore 規則無需變動。

## Risks / Trade-offs

**[clink 使用者依賴 cmd.exe 命令列增強]** → grep 確認 dotfiles 無人裝 clink autorun；若使用者個人在 cmd.exe 仍用 clink，需自行重裝。Mitigation：可逆，`scoop install clink` 即可恢復。

**[winget OS-bundled 不存在的邊角情境]** → 部分 LTSC / Server / 客製化 Win10 image 可能缺 App Installer Store package。Mitigation：使用者可手動 `Add-AppxPackage` 安裝 Microsoft.DesktopAppInstaller；或暫時保留 scoop winget 直到驗證 OS-bundled 可用。此 dotfiles 預設用戶為 Win11 桌面環境，已驗證 OS-bundled 存在。

**[winget-ps 個人腳本依賴 `Find-WinGetPackage` 之類 cmdlet]** → 完整 grep 後 dotfiles 內無使用；若使用者私人 script 有，需自行 `Install-Module Microsoft.WinGet.Client`。Mitigation：可逆。

**[99-command-not-found.ps1 在無 PowerToys 環境的行為]** → `-ErrorAction SilentlyContinue` 保證 silent no-op，不會影響 PowerShell 啟動。Mitigation：N/A（已驗證行為）。

**[dark/vimtutor 軟脫管導致新機 vs 既存機不一致]** → 既存機保留 dark/vimtutor，新機 bootstrap 不再裝。Mitigation：實際上 dark/vimtutor 都無功能性使用，視覺差異無實質影響；若需求出現再走 Wave 4+ 補回。

## Migration Plan

1. Implement:
   - `run_once_install-cli-tools.ps1.tmpl`：移除 5 個工具安裝區塊，補 comment 註明移除原因
   - 新增 `run_once_after_migrate-scoop-wave4.ps1.tmpl`：scoop uninstall 3 個（clink/winget/winget-ps）
   - `Documents/PowerShell/profile.d/99-command-not-found.ps1`：補 header comment
2. 當前機器 `chezmoi apply -v` 確認：
   - scoop 卸載 3 個 entries（clink + winget + winget-ps）
   - `scoop list dark` 與 `scoop list vimtutor` 仍回報已安裝（軟脫管未動）
   - `winget --version` 仍正常（OS-bundled 接手）
   - 新開 PowerShell session 不報錯（99-command-not-found.ps1 silent no-op 或正常載入 PowerToys 模組）
   - PATH 不變
3. `openspec validate scoop-external-wave4 --strict`
4. Code review → squash/normal merge
5. SSH session 驗證（透過 Tailscale 從另一台 SSH 進來）：登入流程正常、無 PATH 缺失警告
