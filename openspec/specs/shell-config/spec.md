# shell-config Specification

## Purpose
規範跨 shell 共用設定(`shell_common`)與平台專屬部份:`.bashrc` 的 WSL 設定、`.zshrc` 的 macOS 設定、shell 啟動時的自動 fetch 提示。

## Requirements

### Requirement: shell_common 提供跨 shell 共用設定
`dot_shell_common` SHALL 包含所有 bash 與 zsh 共用的設定，以 POSIX sh 相容語法撰寫，可被 `.bashrc` 與 `.zshrc` 共同 source。

#### Scenario: bash 環境 source shell_common
- **WHEN** WSL bash 啟動，執行 `~/.bashrc`
- **THEN** `~/.shell_common` 被 source，共用 aliases 與 functions 可用

#### Scenario: zsh 環境 source shell_common
- **WHEN** macOS zsh 啟動，執行 `~/.zshrc`
- **THEN** `~/.shell_common` 被 source，共用 aliases 與 functions 可用

### Requirement: .bashrc 包含 WSL 專屬設定
`dot_bashrc.tmpl` SHALL 在 WSL 環境（`data.isWSL = true`）加入 Windows Terminal 整合設定（OSC 9;9 CWD 回報），並 source `~/.shell_common`。

#### Scenario: WSL 環境部署包含 WT_SESSION 區塊
- **WHEN** chezmoi apply 在 isWSL=true 的環境執行
- **THEN** 部署的 `~/.bashrc` 包含 `WT_SESSION` 判斷與 `PROMPT_COMMAND` 設定

#### Scenario: 非 WSL Linux 環境不包含 WT 設定
- **WHEN** chezmoi apply 在 isWSL=false 的 Linux 環境執行
- **THEN** 部署的 `~/.bashrc` 不含 `WT_SESSION` 區塊

### Requirement: .zshrc 包含 macOS 專屬設定
`dot_zshrc` SHALL 設定 Homebrew PATH、source `~/.shell_common`，以及 zsh 專屬設定（如 `autoload`、補全初始化）。

#### Scenario: macOS 環境部署 .zshrc
- **WHEN** chezmoi apply 在 macOS 執行
- **THEN** `~/.zshrc` 被部署，包含 Homebrew PATH 設定與 shell_common source

#### Scenario: 非 macOS 環境不部署 .zshrc
- **WHEN** chezmoi apply 在 Windows 或 Linux 執行
- **THEN** `~/.zshrc` 不被部署（由 .chezmoiignore 排除）

### Requirement: shell 啟動時自動 fetch 並提示更新
`dot_shell_common` SHALL 包含自動 fetch 機制：每天最多執行一次 `chezmoi git -- fetch`，若有新 commit 則印出提示訊息，不自動 apply。

#### Scenario: 每日首次開啟 shell 時 fetch
- **WHEN** shell 啟動，且 `~/.local/share/chezmoi-last-fetch` 的日期不是今天
- **THEN** 執行 `chezmoi git -- fetch`，更新 flag 檔日期

#### Scenario: 有新版本時顯示提示
- **WHEN** fetch 後 remote 有新 commit
- **THEN** 印出提示訊息（例如：`dotfiles: N new commit(s). Run 'chezmoi update' to apply.`）

#### Scenario: 同一天重複開啟 shell 不重複 fetch
- **WHEN** shell 啟動，且 flag 檔日期為今天
- **THEN** 跳過 fetch，shell 啟動不延遲

### Requirement: shell_common 與 PowerShell profile 各提供一個 glab wrapper

`shell_common` SHALL 定義一個名為 `glab` 的 shell function,Windows 的 profile fragment SHALL 定義其 PowerShell 對應版本。兩者行為一致:解析權杖與 host,設定僅作用於單次呼叫的環境,再轉呼叫真正的 `glab` binary。

wrapper 以 `glab` 為名遮蔽 binary(與另取新名的 `claude-zai` 不同),因為每次 corp 呼叫都需要權杖,不存在「要呼叫未包裝版本」的情境。為避免無窮遞迴,轉呼叫 SHALL 明確指向 binary 而非函式名:bash 用 `command glab`,PowerShell 用 `Get-Command -CommandType Application`。

#### Scenario: bash 環境下 wrapper 生效且不遞迴
- **WHEN** WSL bash 啟動並 source `shell_common`,接著呼叫 `glab api version`
- **THEN** 呼叫抵達 `~/.local/bin/glab` 並成功回傳,過程中不發生函式自我遞迴

#### Scenario: PowerShell 環境下行為一致
- **WHEN** Windows PowerShell profile 載入後呼叫 `glab api version`
- **THEN** 得到與 bash 端相同的結果,錯誤訊息文字亦一致

#### Scenario: 環境設定不外洩到後續呼叫
- **WHEN** wrapper 呼叫結束
- **THEN** 呼叫端 shell 的 `GITLAB_TOKEN` 維持呼叫前的狀態(未設定就仍未設定)
