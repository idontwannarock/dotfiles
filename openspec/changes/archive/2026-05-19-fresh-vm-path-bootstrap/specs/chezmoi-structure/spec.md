## ADDED Requirements

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
