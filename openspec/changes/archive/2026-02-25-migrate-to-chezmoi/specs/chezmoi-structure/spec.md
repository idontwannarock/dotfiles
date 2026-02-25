## ADDED Requirements

### Requirement: Repo 目錄結構符合 chezmoi source 格式
Repo 根目錄 SHALL 作為 chezmoi source dir，所有需要部署到 `$HOME` 的檔案須使用 chezmoi 檔名前綴慣例（`dot_`、`exact_`、`.tmpl` 等）。

#### Scenario: dot_ 前綴對應隱藏檔案
- **WHEN** chezmoi apply 執行
- **THEN** 前綴為 `dot_` 的檔案部署到目標時名稱以 `.` 開頭（e.g., `dot_bashrc` → `~/.bashrc`）

#### Scenario: exact_ 前綴目錄自動清理
- **WHEN** repo 中 `exact_` 前綴目錄內的某個檔案被刪除，且 chezmoi apply 執行
- **THEN** 對應的系統檔案被自動移除

#### Scenario: .tmpl 後綴觸發 template 渲染
- **WHEN** chezmoi apply 處理 `.tmpl` 後綴的檔案
- **THEN** 檔案內容經過 Go template 渲染後部署，目標檔案不含 `.tmpl` 後綴

### Requirement: .chezmoi.toml.tmpl 提供環境偵測
Repo 根目錄 SHALL 包含 `.chezmoi.toml.tmpl`，在 `chezmoi init` 時產生機器專屬的 chezmoi config。

#### Scenario: WSL 環境自動偵測
- **WHEN** chezmoi init 在 Linux 環境執行，且 `uname -r` 輸出包含 `microsoft`
- **THEN** 產生的 config 中 `data.isWSL = true`

#### Scenario: 非 WSL Linux 環境
- **WHEN** chezmoi init 在 Linux 環境執行，且 `uname -r` 不包含 `microsoft`
- **THEN** 產生的 config 中 `data.isWSL = false`

#### Scenario: macOS 環境
- **WHEN** chezmoi init 在 macOS 執行
- **THEN** `data.isWSL = false`，`.chezmoi.os = "darwin"`

### Requirement: .chezmoiignore.tmpl 排除非 dotfile 項目
Repo 根目錄 SHALL 包含 `.chezmoiignore.tmpl`，依 OS 排除不適用的檔案，並永遠排除 repo 本身的管理檔案。

#### Scenario: Windows 專屬目錄在非 Windows 環境排除
- **WHEN** chezmoi apply 在 macOS 或 Linux 執行
- **THEN** `Documents/` 目錄不被部署

#### Scenario: Unix shell 設定在 Windows 排除
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `dot_bashrc`、`dot_zshrc`、`dot_shell_common` 不被部署

#### Scenario: Repo 管理檔案永遠排除
- **WHEN** chezmoi apply 在任何環境執行
- **THEN** `.claude/`、`openspec/`、`docs/`、`README.md`、`ssh/`、`neovim/`、`scoop/` 不被部署

### Requirement: .chezmoiexternal.toml 管理外部二進位
Repo 根目錄 SHALL 包含 `.chezmoiexternal.toml`，宣告需從外部下載的資源（目前為 statusline binary）。

#### Scenario: 正確平台的 statusline binary 被下載
- **WHEN** chezmoi apply 執行
- **THEN** 依 `.chezmoi.os` 與 `.chezmoi.arch` 下載對應的 statusline binary 到 `~/.local/bin/statusline`，且設定為可執行
