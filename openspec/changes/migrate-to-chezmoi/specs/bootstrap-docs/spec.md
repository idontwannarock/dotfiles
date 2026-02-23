## ADDED Requirements

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
