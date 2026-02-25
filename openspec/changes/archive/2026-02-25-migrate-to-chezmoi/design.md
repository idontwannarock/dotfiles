## Context

目前 dotfiles repo 以手動 cp 為主要部署方式，沒有 install script，也沒有跨機器差異偵測。目標是以 chezmoi 作為部署層，保留現有 git repo 位置，並補齊工具依賴的自動安裝。

環境：Windows 11 x2（含 WSL Ubuntu）+ macOS x1。主 shell 為 PowerShell（Windows）與 zsh（macOS）/ bash（WSL）。各機器上此 repo 可能存放於不同路徑。

## Goals / Non-Goals

**Goals:**
- chezmoi 成為唯一的設定部署機制（取代手動 cp）
- 新機器初始化：安裝 git + chezmoi 後一行指令完成所有設定
- 日常更新：`chezmoi update` 顯示 diff 並套用
- 自動偵測並安裝缺少的工具依賴
- README 提供各平台完整 bootstrap 與操作說明

**Non-Goals:**
- 管理套件版本（由各平台 package manager 負責）
- 管理 SSH keys（永遠不納入 chezmoi）
- 管理 Scoop 套件清單（本次暫緩）
- 管理 neovim 設定（已棄用）

## Decisions

### 1. Source dir 由使用者在 init 時指定，不寫死

**決定**：`.chezmoi.toml.tmpl` 不寫死 sourceDir。使用者在各自機器上執行 `chezmoi init` 時，透過 `--source` 參數指定現有 repo 位置，或讓 chezmoi 克隆到自選路徑。

```bash
# 機器上已有 repo（可能在任意位置）
chezmoi init --source /path/to/existing/dotfiles

# 全新機器，克隆到指定位置
chezmoi init --source ~/path/i/prefer git@github.com:你/dotfiles.git

# 全新機器，使用 chezmoi 預設位置
chezmoi init git@github.com:你/dotfiles.git
```

Bootstrap 說明文件中列出上述三種情境，讓每台機器的使用者依實際情況選擇。

**理由**：各機器上此 repo 位置不統一，寫死路徑會造成 init 失敗或行為不一致。

---

### 2. PowerShell：PS5 與 PS7 完全分離

**決定**：`Documents/WindowsPowerShell/profile.d/`（PS5）與 `Documents/PowerShell/profile.d/`（PS7）各自獨立。共用邏輯抽到 `_shared-profile.d/`，由各 profile 的 loader script 一併 source。

```
Documents/
├── _shared-profile.d/        ← 兩者共用的 fragment（純相容語法）
├── PowerShell/               ← PS7 專屬（ternary, ??=, using module 等）
│   ├── Microsoft.PowerShell_profile.ps1  ← loader
│   └── profile.d/
└── WindowsPowerShell/        ← PS5 專屬
    ├── Microsoft.PowerShell_profile.ps1  ← loader
    └── profile.d/
```

**理由**：消除 fragment 內的版本判斷分支，各自使用最適語法。

---

### 3. Bash/Zsh 共用 `shell_common`

**決定**：共用 aliases、functions、starship init 等邏輯放在 `dot_shell_common`，`.bashrc`（WSL）與 `.zshrc`（macOS）都 source 它，各自再加平台專屬內容（WSL 的 `wslpath`/`WT_SESSION`、macOS 的 brew PATH 等）。

**理由**：避免維護兩份幾乎相同的設定。

---

### 4. Claude Code 設定全部以 `exact_` 目錄管理

**決定**：commands 各子目錄與 agents 目錄全部加 `exact_` 前綴。

```
dot_claude/
├── CLAUDE.md
├── exact_commands/
│   ├── exact_opsx/
│   ├── exact_sp/
│   ├── exact_git/
│   ├── exact_code/
│   └── ensure-openspec.md
└── exact_agents/             ← 全部為使用者自訂 agents
    ├── engineering/
    ├── product/
    └── ...
```

**理由**：repo 中移除任何 command 或 agent 後，下次 `chezmoi apply` 自動從系統清除，取代 setup-plugins 的 legacy cleanup 邏輯。agents 全部為使用者自訂，不存在 plugin 管理衝突問題。

---

### 5. Statusline 透過 GitHub Releases + chezmoi external

**決定**：GitHub Actions 在 `claude/statusline/statusline.go` 有變更時，編譯四個平台（linux/amd64、darwin/amd64、darwin/arm64、windows/amd64）並上傳至 GitHub Release（tag: `statusline-latest`，force update）。`.chezmoiexternal.toml` 依 OS/arch 自動下載對應二進位到 `~/.local/bin/statusline`。

**理由**：各機器不需要安裝 Go。

---

### 6. 工具依賴透過 `run_once_` 腳本

**決定**：各 capability 附帶 `run_once_install-<tool>.sh.tmpl`，使用 OS 判斷跳過不適用平台，冪等設計（若已安裝則跳過）。

```
run_once_before_install-deps.sh.tmpl    ← 確保 curl/homebrew 等基礎工具
run_once_install-starship.sh.tmpl
run_once_install-fastfetch.sh.tmpl
run_once_install-claude-code.sh.tmpl
```

**理由**：`chezmoi apply` 成為自給自足的操作。

---

### 7. 自動 fetch 提示機制

**決定**：`shell_common` 與 PowerShell shared fragment 中，以 flag 檔案（`~/.local/share/chezmoi-last-fetch`）限制每天最多 fetch 一次，有新版時印出提示但不自動 apply。

**理由**：維持使用者對「何時套用」的完整控制。

## Risks / Trade-offs

- **Git history 大量 rename**：→ 用單一大 commit 完成所有 rename。
- **現有設定被覆蓋**：→ Bootstrap 說明要求首次 apply 前先執行 `chezmoi diff`。
- **GitHub Release force update**：`statusline-latest` tag 每次更新，舊版本無法回復。→ 接受，statusline 是輔助工具。
- **macOS zsh 設定從零開始**：→ 從 `.bashrc` 提取共用部分到 `shell_common`，`.zshrc` 加 zsh 專屬設定。

## Open Questions

- PS5 與 PS7 的哪些 fragment 可以進 `_shared-profile.d/`？需在實作時逐一評估現有 fragment 的語法相容性。
