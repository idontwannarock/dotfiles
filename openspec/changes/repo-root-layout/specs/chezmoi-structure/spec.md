## MODIFIED Requirements

### Requirement: chezmoi source root 由 .chezmoiroot 指向 home/
Repo root SHALL 包含 `.chezmoiroot`（內容為 `home`），將 `home/` 指定為 chezmoi source root。所有需要部署到 `$HOME` 的檔案 SHALL 置於 `home/` 之下並使用 chezmoi 檔名前綴慣例（`dot_`、`exact_`、`.tmpl` 等）。repo root 其餘項目（CI 原始碼、`docs/`、`tests/`、`openspec/` 等）位於 source root 之外，chezmoi 不會看到，因此無須以 `.chezmoiignore` 排除。

此分界為雙向約束：位於 `home/` 之外的檔案 MUST NOT 被任何部署路徑（alias、wrapper、文件）當作「會出現在使用者機器上」來引用。需要在使用者機器上執行的腳本 SHALL 一律置於 `home/` 之下。

#### Scenario: chezmoi 從 home/ 讀取 source state
- **WHEN** chezmoi apply 或 chezmoi managed 執行
- **THEN** chezmoi source-path 解析為 `<repo>/home`，僅 `home/` 內的檔案被視為 source state

#### Scenario: dot_ 前綴對應隱藏檔案
- **WHEN** chezmoi apply 執行
- **THEN** 前綴為 `dot_` 的檔案部署到目標時名稱以 `.` 開頭（e.g., `dot_bashrc` → `~/.bashrc`）

#### Scenario: exact_ 前綴目錄自動清理
- **WHEN** repo 中 `exact_` 前綴目錄內的某個檔案被刪除，且 chezmoi apply 執行
- **THEN** 對應的系統檔案被自動移除

#### Scenario: .tmpl 後綴觸發 template 渲染
- **WHEN** chezmoi apply 處理 `.tmpl` 後綴的檔案
- **THEN** 檔案內容經過 Go template 渲染後部署，目標檔案不含 `.tmpl` 後綴

#### Scenario: 可執行腳本不置於 source root 之外
- **WHEN** 檢視 repo root 的非部署項目
- **THEN** 其中不含任何供使用者在自己機器上執行的腳本目錄；此類腳本一律位於 `home/dot_local/bin/`

### Requirement: .chezmoiignore.tmpl 排除非 dotfile 項目
chezmoi source root（`home/`）SHALL 包含 `.chezmoiignore.tmpl`，依 OS 排除不適用的檔案。（repo 基礎建設位於 source root 之外，毋須由此排除。）

#### Scenario: Windows 專屬目錄在非 Windows 環境排除
- **WHEN** chezmoi apply 在 macOS 或 Linux 執行
- **THEN** `Documents/` 目錄不被部署

#### Scenario: Unix shell 設定在 Windows 排除
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `dot_bashrc`、`dot_zshrc`、`dot_shell_common` 不被部署

#### Scenario: Repo 基礎建設不被部署（位於 source root 之外）
- **WHEN** chezmoi apply 在任何環境執行
- **THEN** `.claude/`、`openspec/`、`docs/`、`tests/`、`tools/`、`README.md` 等位於 `home/` 之外，不在 chezmoi source state 中，故不被部署
