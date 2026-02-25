## 1. Repo 基礎結構設定

- [x] 1.1 建立 `.chezmoiignore.tmpl`（排除 ssh/、neovim/、scoop/、openspec/、.claude/、docs/、README.md；Windows 排除 Unix shell 設定；非 Windows 排除 Documents/）
- [x] 1.2 建立 `.chezmoi.toml.tmpl`（WSL 偵測，不寫死 sourceDir）
- [x] 1.3 建立 `.chezmoiexternal.toml`（statusline binary 依 OS/arch 從 GitHub Releases 下載）
- [x] 1.4 更新根目錄 `.gitignore`，排除 chezmoi 在 source dir 產生的暫存檔

## 2. Shell 設定遷移（bash / zsh）

- [x] 2.1 建立 `dot_shell_common`，從現有 `bash/.bashrc` 與 `bash/.bash_aliases` 提取共用 aliases、functions、starship init
- [x] 2.2 建立 `dot_shell_common` 的自動 fetch 提示機制（flag 檔限制每日一次）
- [x] 2.3 將 `bash/.bashrc` 重新命名並轉換為 `dot_bashrc.tmpl`，保留 WSL 專屬區塊（WT_SESSION），source `~/.shell_common`
- [x] 2.4 將 `bash/.bash_aliases` 重新命名為 `dot_bash_aliases`（或合併進 shell_common 後移除）
- [x] 2.5 新建 `dot_zshrc`（macOS 用），設定 Homebrew PATH、source `~/.shell_common`，加 zsh 補全初始化
- [x] 2.6 刪除原 `bash/` 目錄下已遷移的檔案

## 3. PowerShell 設定遷移

- [x] 3.1 評估現有 `powershell/profile.d/` 各 fragment，分類為「shared 相容」或「PS7 專屬」或「PS5 專屬」
- [x] 3.2 建立 `Documents/_shared-profile.d/`，放入 shared fragment（如 encoding、git-greeter、fastfetch 等相容語法部分）
- [x] 3.3 建立 `Documents/PowerShell/profile.d/`，放入 PS7 專屬 fragment（PowerToys module、prompt 等 PS7 語法）
- [x] 3.4 建立 `Documents/WindowsPowerShell/profile.d/`，放入 PS5 專屬 fragment（CommandNotFoundAction、prompt 等 PS5 相容語法）
- [x] 3.5 建立 `Documents/PowerShell/Microsoft.PowerShell_profile.ps1`（PS7 loader：source shared + PS7 profile.d）
- [x] 3.6 建立 `Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1`（PS5 loader：source shared + PS5 profile.d）
- [x] 3.7 在 shared fragment 加入自動 fetch 提示機制（與 shell_common 邏輯相同）
- [x] 3.8 刪除原 `powershell/` 目錄下已遷移的檔案

## 4. 跨平台工具設定遷移

- [x] 4.1 將 `starship/starship.toml` 移至 `dot_config/starship/starship.toml`，刪除原目錄
- [x] 4.2 將 `fastfetch/config.jsonc` 與 `fastfetch/ascii.txt` 移至 `dot_config/fastfetch/`，刪除原目錄
- [x] 4.3 將 `vim/.vimrc` 移至 `dot_vimrc`，`vim/.ideavimrc` 移至 `dot_ideavimrc`，`vim/.vim/` 移至 `dot_vim/`，刪除原 `vim/` 目錄

## 5. Claude Code 設定遷移

- [x] 5.1 建立 `dot_claude/` 目錄結構（`CLAUDE.md`、`exact_commands/exact_opsx/`、`exact_commands/exact_sp/`、`exact_commands/exact_git/`、`exact_commands/exact_code/`、`exact_commands/ensure-openspec.md`、`exact_agents/`）
- [x] 5.2 將 `claude/CLAUDE.md` 移至 `dot_claude/CLAUDE.md`
- [x] 5.3 將 `.claude/commands/` 下各子目錄內容移至對應的 `dot_claude/exact_commands/exact_*/`
- [x] 5.4 將 `claude/agents/` 下所有內容移至 `dot_claude/exact_agents/`（保留子目錄結構）
- [x] 5.5 建立 `run_onchange_install-claude-plugins.sh.tmpl`（取代 setup-plugins.sh 的 plugin 安裝邏輯，Unix）
- [x] 5.6 建立 `run_onchange_install-claude-plugins.ps1.tmpl`（取代 setup-plugins.ps1 的 plugin 安裝邏輯，Windows only）
- [x] 5.7 建立 `run_onchange_fix-claude-hooks.ps1.tmpl`（hook 路徑修復、BOM 清除，Windows only）
- [x] 5.8 將 `claude/ensure-openspec.sh` 移至 `dot_local/bin/ensure-openspec.sh`（部署到 `~/.local/bin/`）
- [x] 5.9 刪除原 `claude/` 目錄下已遷移的檔案（保留 `statusline/` 原始碼與 README）

## 6. 工具依賴安裝腳本

- [x] 6.1 建立 `run_once_install-starship.sh.tmpl`（macOS: brew、Linux: curl 官方腳本，Windows: skip）
- [x] 6.2 建立 `run_once_install-fastfetch.sh.tmpl`（macOS: brew、Ubuntu: PPA + apt，Windows: skip）
- [x] 6.3 建立 `run_once_install-claude-code.sh.tmpl`（macOS/Linux: 官方安裝，Windows: skip）
- [x] 6.4 建立 `run_once_install-claude-code.ps1.tmpl`（Windows: 官方 PowerShell 安裝方式）

## 7. GitHub Actions：Statusline 自動發佈

- [x] 7.1 建立 `.github/workflows/release-statusline.yml`（trigger: push to main，path filter: `claude/statusline/**`）
- [x] 7.2 Workflow 中設定 Go build matrix（linux/amd64、darwin/amd64、darwin/arm64、windows/amd64）
- [x] 7.3 Workflow 中設定 GitHub Release upload（tag: `statusline-latest`，force update existing release）
- [x] 7.4 驗證 `.chezmoiexternal.toml` 能正確對應各平台 binary 的下載 URL

## 8. README 文件更新

- [x] 8.1 新增「Bootstrap：各平台前置安裝」章節（git + chezmoi 安裝指令，三平台各自說明）
- [x] 8.2 新增「初始化」章節，說明三種 `chezmoi init` 情境（已有 repo / 克隆到指定位置 / 使用預設位置）
- [x] 8.3 新增「日常操作」章節（`chezmoi update`、`chezmoi diff`、選擇性 apply、`chezmoi cd` 編輯後 commit）
- [x] 8.4 新增「管理範圍」章節（哪些由 chezmoi 管理、哪些不納入及原因）
- [x] 8.5 更新各工具子目錄的 README，移除手動 cp 說明，改為「由 chezmoi 管理，見根目錄 README」

## 9. 驗證

- [ ] 9.1 在現有 Windows 機器執行 `chezmoi init --source <repo路徑>`，確認不報錯
- [ ] 9.2 執行 `chezmoi diff`，確認輸出符合預期（不含 ssh、neovim 等排除項目）
- [ ] 9.3 在 WSL 執行 `chezmoi apply`，確認 bash 設定、starship、fastfetch、Claude Code commands 正確部署
- [ ] 9.4 在 Windows PowerShell 7 與 PowerShell 5 各自驗證 profile 載入正常
- [ ] 9.5 push 一個包含 statusline.go 變更的 commit，確認 GitHub Actions 觸發並產生 Release assets
- [ ] 9.6 執行 `chezmoi apply` 驗證 statusline binary 被下載到 `~/.local/bin/statusline`
