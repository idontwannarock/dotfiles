# bootstrap-docs Specification

## Purpose

定義 README / docs 的 bootstrap 文件需涵蓋的內容：各平台（macOS、Windows、WSL）安裝 git / pwsh / chezmoi 的最小前置步驟、三種 `chezmoi init` 情境、日常操作與工具管理範圍，讓新機器能正確完成初始化。
## Requirements
### Requirement: README 包含各平台最小前置安裝說明
README SHALL 在顯著位置提供各平台（macOS、Windows、WSL Ubuntu）安裝 git 與 chezmoi 的最小指令，格式清晰，類似 GitHub 新建 repo 頁面的快速開始說明。

#### Scenario: 各平台 git 安裝指令存在
- **WHEN** 使用者查閱 README 的 bootstrap 章節
- **THEN** 可找到 macOS（`xcode-select --install` 或 `brew install git`）、Windows（`winget install git.git`）、WSL（`sudo apt install git`）各自的 git 安裝指令

#### Scenario: 各平台 chezmoi 安裝指令存在
- **WHEN** 使用者查閱 README 的 bootstrap 章節
- **THEN** 可找到 macOS/WSL（`curl -fsLS get.chezmoi.io | sh`）與 Windows（`scoop install chezmoi` 或 `winget install twpayne.chezmoi`）的 chezmoi 安裝指令

### Requirement: README 包含三種 chezmoi init 情境說明
README SHALL 說明三種 init 情境，讓已有或未有 repo 的使用者都能依情況選擇正確指令。

#### Scenario: 已有 repo 的 init 說明
- **WHEN** 使用者查閱 init 說明
- **THEN** 可找到「機器上已有 repo」的指令：`chezmoi init --source /path/to/existing/dotfiles`

#### Scenario: 全新機器克隆到指定位置的 init 說明
- **WHEN** 使用者查閱 init 說明
- **THEN** 可找到「全新機器，克隆到自訂路徑」的指令：`chezmoi init --source ~/preferred/path git@github.com:你/dotfiles.git`

#### Scenario: 全新機器使用預設位置的 init 說明
- **WHEN** 使用者查閱 init 說明
- **THEN** 可找到「全新機器，使用 chezmoi 預設位置」的指令：`chezmoi init --apply git@github.com:你/dotfiles.git`

### Requirement: README 包含日常操作指南
README SHALL 包含日常使用的常見操作說明，包含同步更新、查看差異、選擇性套用等。

#### Scenario: 日常同步指令說明
- **WHEN** 使用者查閱日常操作章節
- **THEN** 可找到：`chezmoi update`（pull + apply）、`chezmoi diff`（只看差異）、`chezmoi apply ~/.config/starship/starship.toml`（套用單一檔案）的說明

#### Scenario: 修改設定後同步到 repo 的說明
- **WHEN** 使用者查閱如何將本機修改同步回 repo 的說明
- **THEN** 可找到 `chezmoi cd` 進入 source dir 後使用 git 操作的說明

### Requirement: README 包含工具管理說明
README SHALL 說明哪些工具由 chezmoi 管理（含自動安裝）、哪些不納入（ssh keys、scoop packages 等）及原因。

#### Scenario: 管理範圍說明清晰
- **WHEN** 使用者查閱 README
- **THEN** 可明確得知哪些設定由 chezmoi 管理、哪些需要手動處理

### Requirement: Windows bootstrap 不以 scoop 為 git 的必要安裝方式
README 的 Windows bootstrap 章節 SHALL 以 `winget install Git.Git` 安裝 git、`winget install twpayne.chezmoi` 安裝 chezmoi，且 SHALL NOT 將 scoop 描述為 git 的必要前提。scoop SHALL 僅以「選用（GUI app 參考清單）」呈現。README SHALL NOT 保留「git 一律透過 scoop、其他安裝方式會導致 script 執行失敗」之類的前提敘述（chezmoi 的 git-bash interpreter 改為偵測解析後已不成立，見 chezmoi-structure）。

#### Scenario: Windows bootstrap 用 winget 裝 git 與 chezmoi
- **WHEN** 使用者查閱 README 的 Windows bootstrap 章節
- **THEN** 可找到 `winget install Git.Git` 與 `winget install twpayne.chezmoi`，且無「git 必須經 scoop」之前提

#### Scenario: scoop 降為選用
- **WHEN** 使用者查閱 README
- **THEN** scoop 僅出現在「選用 / GUI app」脈絡，不在 chezmoi 運作的必要 bootstrap 步驟中

### Requirement: Windows bootstrap 文件化 pwsh 7 前置條件與 MSI 取得方式

README 的 Windows bootstrap 章節 SHALL 將 PowerShell 7（pwsh）列為與 git 同級的前置條件（chezmoi 用它執行 `.ps1` run script，無 fallback；缺了 pwsh，第一個 `.ps1` 安裝腳本即 `exec: "pwsh": not found` 而中止）。文件 SHALL 說明 `winget install Microsoft.PowerShell` 交付的是 **MSIX** 版，並 SHALL 指出若要 MSI 版（落 `C:\Program Files\PowerShell\7`、非 Store）需改用 GitHub release 的 `PowerShell-<ver>-win-x64.msi`，可參照 `~/.local/bin/switch-pwsh-to-msi.ps1`。`docs/powershell.md` SHALL 與此一致。

#### Scenario: pwsh 列為 Windows 前置條件

- **WHEN** 使用者查閱 README 的 Windows bootstrap 章節
- **THEN** 可找到 pwsh 7 被列為前置條件，且有 `winget install Microsoft.PowerShell` 安裝指令

#### Scenario: 文件指出 MSI 取得方式

- **WHEN** 使用者想要非 Store 的 MSI 版 pwsh
- **THEN** README / `docs/powershell.md` 指出 winget 交付的是 MSIX、MSI 在 GitHub release，並指向 switch helper

