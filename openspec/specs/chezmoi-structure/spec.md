# chezmoi-structure Specification

## Purpose
定義 chezmoi source root 佈局與環境偵測慣例:`.chezmoiroot` 指向 `home/`、`.chezmoi.toml.tmpl` 偵測 OS 並注入 PATH、`.chezmoiignore` 排除非 dotfile、`.chezmoiexternal.toml` 管外部二進位、git-bash interpreter 偵測。

## Requirements

### Requirement: chezmoi source root 由 .chezmoiroot 指向 home/
Repo root SHALL 包含 `.chezmoiroot`（內容為 `home`），將 `home/` 指定為 chezmoi source root。所有需要部署到 `$HOME` 的檔案 SHALL 置於 `home/` 之下並使用 chezmoi 檔名前綴慣例（`dot_`、`exact_`、`.tmpl` 等）。repo root 其餘項目（CI 原始碼、`docs/`、`tests/`、`openspec/` 等）位於 source root 之外，chezmoi 不會看到，因此無須以 `.chezmoiignore` 排除。

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

### Requirement: .chezmoi.toml.tmpl 提供環境偵測
chezmoi source root（`home/`）SHALL 包含 `.chezmoi.toml.tmpl`，在 `chezmoi init` 時產生機器專屬的 chezmoi config。

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
chezmoi source root（`home/`）SHALL 包含 `.chezmoiignore.tmpl`，依 OS 排除不適用的檔案。（repo 基礎建設位於 source root 之外，毋須由此排除。）

#### Scenario: Windows 專屬目錄在非 Windows 環境排除
- **WHEN** chezmoi apply 在 macOS 或 Linux 執行
- **THEN** `Documents/` 目錄不被部署

#### Scenario: Unix shell 設定在 Windows 排除
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `dot_bashrc`、`dot_zshrc`、`dot_shell_common` 不被部署

#### Scenario: Repo 基礎建設不被部署（位於 source root 之外）
- **WHEN** chezmoi apply 在任何環境執行
- **THEN** `.claude/`、`openspec/`、`docs/`、`README.md`、`neovim/`、`passgen/` 等位於 `home/` 之外，不在 chezmoi source state 中，故不被部署

### Requirement: .chezmoi.toml.tmpl 為所有 chezmoi-spawned scripts 注入 ~/.local/bin 到 PATH
`.chezmoi.toml.tmpl` SHALL 包含 `[scriptEnv]` 區塊，將 `~/.local/bin` prepend 到 PATH 環境變數。此設定 SHALL 透過 chezmoi 套用到所有由 chezmoi 啟動的子程序，包含 `run_*` scripts、modify_ files 經 `[interpreters.sh]` 啟動的 bash 程序、以及 hooks。

此 requirement 確保「chezmoi-external 安裝到 `~/.local/bin/` 的 CLI 工具」能在 modify scripts 內以 bare command 呼叫，無需仰賴使用者預先設定 User PATH。

#### Scenario: Fresh VM 第一次 chezmoi init 後 chezmoi.toml 含 scriptEnv
- **WHEN** 在從未跑過 chezmoi 的 Windows VM 上執行 `chezmoi init <repo>`
- **THEN** 產生的 `~/.config/chezmoi/chezmoi.toml` 包含 `[scriptEnv]` 區塊，其中 `PATH` 值以 `~/.local/bin` 開頭（後接原系統 PATH 內容）

#### Scenario: modify_ 經 bash interpreter 啟動時 PATH 含 ~/.local/bin
- **WHEN** chezmoi apply 在 Windows 上執行 `dot_claude/modify_settings.json.sh.tmpl`，並透過 `[interpreters.sh]` spawn `bash`
- **THEN** bash 程序的 `PATH` 環境變數開頭為 `~/.local/bin`（Git Bash 翻譯後形式 `/c/Users/<user>/.local/bin`）

#### Scenario: scriptEnv 不覆寫原 PATH
- **WHEN** chezmoi 啟動任何子程序
- **THEN** scriptEnv 注入的 PATH **prepend** 而非 replace；原系統 PATH 內所有條目仍保留在 `~/.local/bin` 之後

### Requirement: .chezmoiexternal.toml 管理外部二進位
chezmoi source root（`home/`）SHALL 包含 `.chezmoiexternal.toml`，宣告需從外部下載的資源（statusline、passgen binary）。

#### Scenario: 正確平台的 statusline binary 被下載
- **WHEN** chezmoi apply 執行
- **THEN** 依 `.chezmoi.os` 與 `.chezmoi.arch` 下載對應的 statusline binary 到 `~/.local/bin/statusline`，且設定為可執行

### Requirement: git-bash interpreter 由偵測候選清單解析（不再硬依賴 scoop）
Windows 上 chezmoi 的 `[interpreters.sh]` command SHALL 由「已知 Git-for-Windows 安裝 root 的有序候選清單」偵測解析，取第一個其 `bin\bash.exe` 存在者，而非硬指 `~/scoop/apps/git/current/bin/bash.exe`。候選順序 SHALL 為非-scoop 優先、scoop 殿後（backward-compat）：
1. `~/.local/opt/git/bin/bash.exe`（PortableGit）
2. `C:\Program Files\Git\bin\bash.exe`（winget / 官方安裝器）
3. `~/scoop/apps/git/current/bin/bash.exe`（scoop）

偵測 SHALL NOT 使用 PATH 搜尋（`where bash` / `lookPath`）——該方式會錯選 WSL `C:\Windows\System32\bash.exe` 或裸 `usr\bin\bash.exe`。候選 SHALL 以 `bin\bash.exe`（MSYSTEM wrapper）為準。

`.chezmoi.toml.tmpl` SHALL 在 render 時以 `stat`-based first-existing 掃描 static 清單寫入 interpreter。`run_onchange_before_patch-chezmoi-config.ps1.tmpl` SHALL 以同清單（PowerShell）外加可選的 `HKLM/HKCU\SOFTWARE\GitForWindows\InstallPath` registry probe 解析、並在 config 的 interpreter 與偵測不符時 self-heal 改寫；其既有 guard SHALL 檢查偵測到的 git-bash 路徑（非硬指 scoop）。

#### Scenario: 偵測優先非-scoop git
- **WHEN** 機器上同時有 `C:\Program Files\Git\bin\bash.exe`（winget）與 scoop git
- **THEN** `[interpreters.sh]` 解析為 Program Files 的 `bin\bash.exe`（清單 (2) 在 (3) 之前）

#### Scenario: 僅有 scoop git 的舊機器不破壞
- **WHEN** 機器上只有 scoop git
- **THEN** 偵測命中清單 (3)，interpreter 為 `~/scoop/apps/git/current/bin/bash.exe`，chezmoi apply 正常

#### Scenario: 非預設目錄的官方/winget 安裝由 registry probe 補捉
- **WHEN** git 由官方安裝器裝在非預設目錄（static 清單未命中），但 `HKLM\SOFTWARE\GitForWindows\InstallPath` 指向它
- **THEN** `patch-chezmoi-config` 經 registry probe 解析到該 git，self-heal 改寫 interpreter

#### Scenario: 不使用 PATH 搜尋
- **WHEN** 偵測 git-bash
- **THEN** 不呼叫 `where bash` / `lookPath`；不選用 `C:\Windows\System32\bash.exe` 或任何 `usr\bin\bash.exe`
