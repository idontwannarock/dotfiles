## Why

目前 dotfiles 同步完全依賴手動 git pull，沒有差異感知機制，也沒有安裝腳本，每次在新環境或更新後都需要手動對應每個工具的設定，容易出錯且難以維護。遷移到 chezmoi 可以提供宣告式的檔案部署、內建 diff、一行初始化新機器等能力，同時保留對套用時機的完整控制。

## What Changes

- 將 repo 目錄結構重組為 chezmoi source 格式（檔案加 `dot_`、`exact_` 等前綴）
- 新增 `.chezmoi.toml.tmpl`（WSL 偵測、source dir 設定）與 `.chezmoiignore.tmpl`
- 分離 PowerShell 5 與 PowerShell 7 的 profile 樹，各自使用專屬語法
- 新增 `.zshrc` 支援 macOS，與 WSL bash 共用 `shell_common`
- Claude Code commands/agents 目錄改用 `exact_` 部署（自動清理移除的檔案）
- setup-plugins 邏輯拆解為 chezmoi `run_onchange_` scripts
- 新增 GitHub Actions 流程，push to main 時自動編譯 statusline 多平台二進位並發佈至 GitHub Releases；chezmoi `external` 機制取代手動安裝
- 各工具設定部署時透過 `run_once_` scripts 確保該工具已安裝（starship、fastfetch、Claude Code 等）
- 新增開啟 shell 時自動 fetch + 提示有新版的機制
- README 新增：各平台 bootstrap 前置步驟（git + chezmoi 安裝指令）、日常操作說明、新機器初始化說明

## Capabilities

### New Capabilities

- `chezmoi-structure`: repo 目錄結構與檔案命名符合 chezmoi source 格式，包含 `.chezmoi.toml.tmpl`、`.chezmoiignore.tmpl`、`.chezmoiexternal.toml`
- `shell-config`: WSL bash 與 macOS zsh 共用 `shell_common`，各自有獨立 rc 檔；包含開機自動 fetch 提示
- `powershell-config`: PS5 與 PS7 profile 完全分離，各自有獨立的 `profile.d/` 目錄
- `claude-config`: Claude Code 設定（CLAUDE.md、commands、agents）透過 chezmoi `exact_` 目錄部署，setup-plugins 改為 `run_onchange_` scripts
- `tool-dependencies`: 各工具設定部署時的 `run_once_` 安裝腳本（starship、fastfetch、Claude Code 等各平台安裝方式）
- `statusline-release`: GitHub Actions 自動編譯 statusline 多平台二進位，chezmoi external 自動下載
- `bootstrap-docs`: README 各平台最小前置安裝說明（git、chezmoi）與完整操作指南

### Modified Capabilities

（無既有 spec 受影響）

## Impact

- **Repo 結構**：大量檔案重新命名與搬移，git history 會有大量 rename
- **現有手動設定**：首次在已有設定的機器上 apply 前需執行 `chezmoi diff` 確認差異
- **GitHub Actions**：需要新增 workflow，statusline 需要 Go build environment
- **PowerShell profile**：PS5 與 PS7 的 profile.d 部分 fragment 可共用，需評估拆分方式
- **setup-plugins.sh / .ps1**：邏輯拆解為 chezmoi scripts 後，原腳本可退役
