## ADDED Requirements

### Requirement: Template 片段目錄結構
`.chezmoitemplates/` SHALL 按「檔案名稱/平台」組織 template 片段，包含以下結構：
- `bashrc/windows` — Git Bash 專用 `.bashrc`
- `bashrc/linux` — Linux/WSL 專用 `.bashrc`
- `shell-common/base` — 三平台共用的 shell 設定
- `shell-common/windows` — Windows 專屬擴充（template base）
- `shell-common/linux` — Linux 專屬擴充（template base）
- `shell-common/darwin` — macOS 專屬擴充（template base）
- `zshrc/darwin` — macOS 專用 `.zshrc`

#### Scenario: 目錄結構完整
- **WHEN** 檢查 `.chezmoitemplates/` 目錄
- **THEN** 上述 7 個檔案全部存在

### Requirement: 入口檔依 OS 選擇 template 片段
`dot_bashrc.tmpl`、`dot_shell_common.tmpl`、`dot_zshrc.tmpl` SHALL 作為入口檔，依 `.chezmoi.os` 使用 `{{ template }}` 載入對應平台的 template 片段。

#### Scenario: Windows 上 .bashrc 使用 bashrc/windows
- **WHEN** `chezmoi.os` 為 `windows`
- **THEN** `dot_bashrc.tmpl` include `bashrc/windows` 片段

#### Scenario: Linux 上 .bashrc 使用 bashrc/linux
- **WHEN** `chezmoi.os` 為 `linux`
- **THEN** `dot_bashrc.tmpl` include `bashrc/linux` 片段並傳入 template data（`.`）

#### Scenario: macOS 上 .zshrc 使用 zshrc/darwin
- **WHEN** `chezmoi.os` 為 `darwin`
- **THEN** `dot_zshrc.tmpl` include `zshrc/darwin` 片段

#### Scenario: 各平台 .shell_common 使用對應片段
- **WHEN** `chezmoi.os` 為 `windows`、`linux` 或 `darwin`
- **THEN** `dot_shell_common.tmpl` include 對應的 `shell-common/{os}` 片段

### Requirement: shell-common 平台片段 include base
每個平台的 `shell-common/{platform}` 片段 SHALL 透過 `{{ template "shell-common/base" . }}` 引入共用核心，再附加平台專屬設定。

#### Scenario: Windows shell-common 包含 base 內容
- **WHEN** 渲染 `shell-common/windows`
- **THEN** 輸出包含 `shell-common/base` 的完整內容

#### Scenario: 各平台 shell-common 輸出包含 base
- **WHEN** 渲染任一平台的 `shell-common/{platform}`
- **THEN** 輸出 MUST 包含 worklogs aliases 和 `_dotfiles_check_update` 函式

### Requirement: 部署結果與重構前一致
重構後各平台最終部署的 `~/.bashrc`、`~/.shell_common`、`~/.zshrc` 內容 SHALL 與重構前完全相同。

#### Scenario: Linux/WSL 部署結果不變
- **WHEN** 在 Linux 上執行 `chezmoi apply`
- **THEN** `~/.bashrc` 和 `~/.shell_common` 內容與重構前一致

#### Scenario: macOS 部署結果不變
- **WHEN** 在 macOS 上執行 `chezmoi apply`
- **THEN** `~/.zshrc` 和 `~/.shell_common` 內容與重構前一致

#### Scenario: Windows 部署結果不變
- **WHEN** 在 Windows 上執行 `chezmoi apply`
- **THEN** `~/.bashrc` 和 `~/.shell_common` 內容與重構前一致

### Requirement: .chezmoiignore 使用 target 路徑
`.chezmoiignore.tmpl` SHALL 使用 target 路徑名稱（如 `.bashrc`）而非 source 名稱（如 `dot_bashrc.tmpl`）來定義忽略規則。

#### Scenario: macOS 不部署 .bashrc
- **WHEN** `chezmoi.os` 為 `darwin`
- **THEN** `.bashrc` 出現在 ignore 清單中

#### Scenario: 非 macOS 不部署 .zshrc
- **WHEN** `chezmoi.os` 不是 `darwin`
- **THEN** `.zshrc` 出現在 ignore 清單中

### Requirement: EOL 控制
`.gitattributes` SHALL 對 `.chezmoitemplates/` 下的所有檔案強制使用 LF 行尾。

#### Scenario: template 片段使用 LF
- **WHEN** 在 Windows 上 checkout `.chezmoitemplates/` 下的檔案
- **THEN** 檔案行尾為 LF 而非 CRLF
