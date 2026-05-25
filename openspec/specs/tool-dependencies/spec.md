## Purpose

定義跨平台（Windows / macOS / Linux）dotfiles 部署期間 CLI 工具的安裝策略：哪些工具透過 `run_once_install-*` 腳本由各 OS 套件管理器（Homebrew / apt / Scoop）安裝、哪些 Windows 工具改由 `.chezmoiexternal.toml` 直接從 GitHub Release 或官方 CDN 下載 binary 至 `~/.local/bin/`，以及對應的一次性遷移腳本（`run_once_after_migrate-scoop-*`）負責清理舊有 scoop 安裝。
## Requirements
### Requirement: chezmoi apply 自動安裝缺少的工具
每個部署設定檔的 capability SHALL 附帶對應的 `run_once_` 安裝腳本，確保工具在設定被部署前已安裝。腳本採冪等設計（工具已存在則跳過），並依 OS 跳過不適用平台。

#### Scenario: 工具未安裝時自動安裝
- **WHEN** chezmoi apply 執行，且對應工具尚未安裝
- **THEN** `run_once_install-<tool>.sh.tmpl` 執行，完成工具安裝

#### Scenario: 工具已安裝時跳過
- **WHEN** chezmoi apply 執行，且對應工具已存在
- **THEN** 安裝腳本執行但無實際操作，不重複安裝

#### Scenario: 不適用平台跳過安裝腳本
- **WHEN** chezmoi apply 在與工具不相容的 OS 執行（如 Windows 執行 Linux-only 工具腳本）
- **THEN** 腳本透過 OS 判斷提前退出，不嘗試安裝

### Requirement: Starship 安裝腳本支援 macOS 與 Linux
`run_once_install-starship.sh.tmpl` SHALL 在 macOS（使用 Homebrew）與 Linux（使用官方安裝腳本）上安裝 starship。Windows 上 starship SHALL 由 `.chezmoiexternal.toml` 下載 GitHub Release 的 `starship-x86_64-pc-windows-msvc.zip` 並抽出 `starship.exe` 至 `~/.local/bin/starship.exe`，不再經由 Scoop。

#### Scenario: macOS 上安裝 starship
- **WHEN** chezmoi apply 在 macOS 執行，且 starship 未安裝
- **THEN** 使用 `brew install starship` 安裝

#### Scenario: Linux 上安裝 starship
- **WHEN** chezmoi apply 在 Linux（WSL）執行，且 starship 未安裝
- **THEN** 使用官方 curl install script 安裝

#### Scenario: Windows 上下載 starship binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 GitHub Release 下載 pinned 版本的 `starship-x86_64-pc-windows-msvc.zip`，抽出 `starship.exe` 至 `~/.local/bin/`，設為 executable

#### Scenario: Windows 上 starship 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-01-runtimes.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "starship"`

### Requirement: Fastfetch 安裝腳本支援 macOS 與 Linux
`run_once_install-fastfetch.sh.tmpl` SHALL 在 macOS（Homebrew）與 Ubuntu/Debian（PPA）上安裝 fastfetch，Windows 上跳過。

#### Scenario: macOS 上安裝 fastfetch
- **WHEN** chezmoi apply 在 macOS 執行，且 fastfetch 未安裝
- **THEN** 使用 `brew install fastfetch` 安裝

#### Scenario: Ubuntu 上安裝 fastfetch
- **WHEN** chezmoi apply 在 Ubuntu（WSL）執行，且 fastfetch 未安裝
- **THEN** 新增 PPA 並以 `apt install fastfetch` 安裝

### Requirement: Claude Code 安裝腳本支援全平台
`run_once_install-claude-code.sh.tmpl`（Unix）與 `run_once_install-claude-code.ps1.tmpl`（Windows）SHALL 在對應平台安裝 Claude Code CLI，若已安裝則跳過。

#### Scenario: macOS/Linux 上安裝 Claude Code
- **WHEN** chezmoi apply 在 macOS 或 Linux 執行，且 `claude` 指令不存在
- **THEN** 使用官方安裝方式安裝 Claude Code

#### Scenario: Windows 上安裝 Claude Code
- **WHEN** chezmoi apply 在 Windows 執行，且 `claude` 指令不存在
- **THEN** 使用 PowerShell 安裝腳本安裝 Claude Code

### Requirement: Zellij 在 Windows 上由 chezmoi-external 安裝
Windows 上 zellij SHALL 由 `.chezmoiexternal.toml` 下載 GitHub Release 的 `zellij-x86_64-pc-windows-msvc.zip` 並抽出 `zellij.exe` 至 `~/.local/bin/zellij.exe`。Linux 與 macOS 上由各自 OS 套件管理器負責，不在本要求範圍。

#### Scenario: Windows 上下載 zellij binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 下載 pinned 版本的 `zellij-x86_64-pc-windows-msvc.zip`，抽出 `zellij.exe` 至 `~/.local/bin/`，設為 executable

#### Scenario: SSH session 下 zellij 可直接啟動
- **WHEN** 經由 Tailscale + Win32-OpenSSH 連入 Windows，於 PowerShell 執行 `zellij`
- **THEN** 解析到 `~/.local/bin/zellij.exe` 並正常啟動，無需 `35-scoop-ssh-shims.ps1` 的 PATH 重寫

### Requirement: uv 在 Windows 上由 chezmoi-external 安裝
Windows 上 uv SHALL 由 `.chezmoiexternal.toml` 下載 GitHub Release 的 `uv-x86_64-pc-windows-msvc.zip` 並抽出 `uv.exe` 至 `~/.local/bin/uv.exe`。

#### Scenario: Windows 上下載 uv binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 下載 pinned 版本的 `uv-x86_64-pc-windows-msvc.zip`，抽出 `uv.exe` 至 `~/.local/bin/`，設為 executable

#### Scenario: Windows 上 uv 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-01-runtimes.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "uv"`

### Requirement: jq 在 Windows 上由 chezmoi-external 安裝
Windows 上 jq SHALL 由 `.chezmoiexternal.toml` 直接下載 GitHub Release 的 `jq-windows-amd64.exe` 至 `~/.local/bin/jq.exe`（jq 是裸 `.exe`，非 archive）。Fresh VM 上由於 external 在 step 4 才執行（晚於同階段、字母順序較早的 modify_ files），SHALL 另由 `run_onchange_before_setup-paths.ps1.tmpl`（step 3）負責在 modify_ 跑之前把 jq.exe 落地；該 setup-paths 腳本與 external 用同一 URL 與 pinned version，確保兩處不會出現版本飄移。

#### Scenario: Windows 上下載 jq binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 `https://github.com/jqlang/jq/releases/download/jq-<version>/jq-windows-amd64.exe` 下載至 `~/.local/bin/jq.exe`，設為 executable

#### Scenario: Windows 上 jq 不再經由 Scoop prereq 腳本
- **WHEN** 在 Windows 上的 `run_onchange_before_install-prereqs.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Ensure-ScoopTool "jq"`

#### Scenario: Fresh VM 上 jq.exe 早於 modify_settings 落地
- **WHEN** 全新 Windows VM 上 `chezmoi init <repo> && chezmoi apply`，且 modify_ 階段（step 4）尚未開始
- **THEN** `run_onchange_before_setup-paths.ps1.tmpl`（step 3）已從 GitHub Release 下載 jq.exe 至 `~/.local/bin/`；後續 `modify_settings.json.sh.tmpl` 啟動的 bash 程序透過 scriptEnv 注入的 PATH 解析到該 jq.exe 並成功 patch settings.json

#### Scenario: 既有機器上 setup-paths 與 external 都不重做下載
- **WHEN** Windows 機器上 `~/.local/bin/jq.exe` 已存在且版本與 pinned 一致
- **THEN** setup-paths 偵測檔案存在後 no-op；step 4 的 external entry 因 hash 一致也 skip 重下

### Requirement: Fresh VM bootstrap 確保 modify_ 依賴的 CLI 在執行前可用
Windows 上 SHALL 存在 `run_onchange_before_setup-paths.ps1.tmpl`，在 chezmoi apply 的 `run_before_` 階段（早於 step 4 update entries）執行，職責有二：

1. **確保 ~/.local/bin/jq.exe 物理存在**：若不存在，從 GitHub Release（與 `.chezmoiexternal.toml` 同一 URL 與 pinned version）以 `Invoke-WebRequest` 下載並設為 executable。Fresh VM 上此步必跑；既有機器上 jq.exe 已存在 → no-op。
2. **確保 User PATH 含 ~/.local/bin**：若不存在於 User-scope `Path` 環境變數，prepend 之並持久化（給未來 shell session）。已存在 → no-op。

腳本 SHALL 為冪等：對於兩個職責，已達標時 SHALL 跳過實際操作而非報錯。

#### Scenario: Fresh VM 上 setup-paths 下載 jq.exe
- **WHEN** Windows VM 上 `~/.local/bin/jq.exe` 不存在，chezmoi apply 執行至 `run_before_` 階段
- **THEN** setup-paths 透過 `Invoke-WebRequest` 從 `https://github.com/jqlang/jq/releases/download/jq-<version>/jq-windows-amd64.exe` 下載 jq.exe 至 `~/.local/bin/jq.exe`；下載失敗時 throw 終止 apply

#### Scenario: 既有機器上 setup-paths 為 no-op
- **WHEN** Windows 機器上 `~/.local/bin/jq.exe` 已存在
- **THEN** setup-paths 不重新下載 jq.exe

#### Scenario: Fresh VM 上 User PATH 加入 ~/.local/bin
- **WHEN** Windows VM 上 User PATH 不含 `~/.local/bin`（展開後等於 `%USERPROFILE%\.local\bin`），chezmoi apply 執行至 `run_before_` 階段
- **THEN** setup-paths 透過 `[Environment]::SetEnvironmentVariable("Path", ..., "User")` 將 `~/.local/bin` prepend 到 User PATH

#### Scenario: 既有機器上 User PATH 不重複加 ~/.local/bin
- **WHEN** Windows 機器上 User PATH 已含 `~/.local/bin`（不論位置）
- **THEN** setup-paths 不修改 User PATH

#### Scenario: setup-paths 早於 modify_settings.json 執行
- **WHEN** chezmoi apply 進入 step 4 update entries
- **THEN** `~/.local/bin/jq.exe` 已存在於檔案系統，且 chezmoi 子程序的 PATH 包含 `~/.local/bin`（由 `[scriptEnv]` 提供），因此 `modify_settings.json.sh.tmpl` 內的 `jq` 呼叫能正常解析

### Requirement: ripgrep 在 Windows 上由 chezmoi-external 安裝
Windows 上 ripgrep SHALL 由 `.chezmoiexternal.toml` 下載 GitHub Release 的 `ripgrep-<version>-x86_64-pc-windows-msvc.zip`，抽出子目錄 `ripgrep-<version>-x86_64-pc-windows-msvc/rg.exe` 至 `~/.local/bin/rg.exe`。

#### Scenario: Windows 上下載 ripgrep binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 下載 pinned 版本的 `ripgrep-<version>-x86_64-pc-windows-msvc.zip`，從 archive 內子目錄抽出 `rg.exe` 至 `~/.local/bin/`，設為 executable

### Requirement: Wave 1 一次性遷移腳本
`run_once_after_migrate-scoop-to-external.ps1.tmpl` SHALL 在 Windows 上執行一次性遷移：（1）卸載已存在的 scoop starship/zellij/uv/jq/ripgrep；（2）調整 User PATH 確保 `~/.local/bin` 早於 `~/scoop/shims`。腳本為冪等：若 scoop 未安裝對應套件、或 PATH 順序已正確，對應步驟視為 no-op。

#### Scenario: 已安裝 scoop 套件被卸載
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list starship`（或其他 4 個）回報已安裝
- **THEN** 腳本執行 `scoop uninstall <pkg>`，scoop apps 目錄該套件被移除

#### Scenario: scoop 套件未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報未安裝
- **THEN** 腳本不執行 `scoop uninstall`，繼續處理 PATH

#### Scenario: User PATH 重排
- **WHEN** User PATH 中 `~/.local/bin` 的索引位置晚於 `~/scoop/shims`，或 `~/.local/bin` 不在 PATH 中
- **THEN** 腳本將 `~/.local/bin` 移除（若已在）並重新插入到 `~/scoop/shims` 之前；其他 PATH 條目原樣保留

#### Scenario: User PATH 順序已正確時 no-op
- **WHEN** User PATH 中 `~/.local/bin` 已位於 `~/scoop/shims` 之前
- **THEN** 腳本不修改 PATH

#### Scenario: PATH 變更後提示重開 session
- **WHEN** 腳本修改了 User PATH
- **THEN** 印出 warning 提醒使用者重開 terminal/SSH session 以讓變更生效

### Requirement: kubectl 在 Windows 上由 chezmoi-external 安裝
Windows 上 kubectl SHALL 由 `.chezmoiexternal.toml` 直接從 Kubernetes 官方 CDN（`dl.k8s.io`）下載對應版本的 `kubectl.exe` 至 `~/.local/bin/kubectl.exe`。版本以 `$kubectlVersion` 變數 pinned。

#### Scenario: Windows 上下載 kubectl binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 `https://dl.k8s.io/release/v<version>/bin/windows/amd64/kubectl.exe` 下載至 `~/.local/bin/kubectl.exe`，設為 executable

#### Scenario: Windows 上 kubectl 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-containers.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "kubectl"`

### Requirement: kubelogin 在 Windows 上由 chezmoi-external 安裝
Windows 上 kubelogin SHALL 由 `.chezmoiexternal.toml` 下載 GitHub Release `Azure/kubelogin` 的 `kubelogin-win-amd64.zip`，抽出 `bin/windows_amd64/kubelogin.exe` 至 `~/.local/bin/kubelogin.exe`。

#### Scenario: Windows 上下載 kubelogin binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 下載 `kubelogin-win-amd64.zip`，抽出內部 `bin/windows_amd64/kubelogin.exe` 至 `~/.local/bin/`，設為 executable

#### Scenario: Windows 上 kubelogin 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-containers.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "kubelogin"`

### Requirement: yt-dlp 在 Windows 上由 chezmoi-external 安裝
Windows 上 yt-dlp SHALL 由 `.chezmoiexternal.toml` 直接下載 GitHub Release `yt-dlp/yt-dlp` 的裸 `yt-dlp.exe` 至 `~/.local/bin/yt-dlp.exe`。版本使用 CalVer `YYYY.MM.DD` 格式（無 `v` prefix）。

#### Scenario: Windows 上下載 yt-dlp binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 `https://github.com/yt-dlp/yt-dlp/releases/download/<version>/yt-dlp.exe` 下載至 `~/.local/bin/yt-dlp.exe`，設為 executable

#### Scenario: Windows 上 yt-dlp 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "yt-dlp"`

### Requirement: hugo (extended) 在 Windows 上由 chezmoi-external 安裝
Windows 上 hugo SHALL 由 `.chezmoiexternal.toml` 下載 GitHub Release `gohugoio/hugo` 的 `hugo_extended_<version>_windows-amd64.zip`，抽出 `hugo.exe` 至 `~/.local/bin/hugo.exe`。一律使用 extended variant（含 SASS/SCSS 支援），不另裝 vanilla hugo。

#### Scenario: Windows 上下載 hugo extended binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 下載 `hugo_extended_<version>_windows-amd64.zip`，抽出 root 的 `hugo.exe` 至 `~/.local/bin/`，設為 executable

#### Scenario: Windows 上 hugo 與 hugo-extended 都不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "hugo"` 或 `Install-ScoopPackage "hugo-extended"`

### Requirement: nexttrace 在 Windows 上由 chezmoi-external 安裝
Windows 上 nexttrace SHALL 由 `.chezmoiexternal.toml` 直接下載 GitHub Release `nxtrace/NTrace-V1` 的裸 `nexttrace_windows_amd64.exe` 至 `~/.local/bin/nexttrace.exe`。

#### Scenario: Windows 上下載 nexttrace binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 `https://github.com/nxtrace/NTrace-V1/releases/download/v<version>/nexttrace_windows_amd64.exe` 下載至 `~/.local/bin/nexttrace.exe`，設為 executable

#### Scenario: Windows 上 nexttrace 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "nexttrace"`

### Requirement: golangci-lint 在 Windows 上由 chezmoi-external 安裝
Windows 上 golangci-lint SHALL 由 `.chezmoiexternal.toml` 下載 GitHub Release `golangci/golangci-lint` 的 `golangci-lint-<version>-windows-amd64.zip`，抽出 `golangci-lint-<version>-windows-amd64/golangci-lint.exe` 至 `~/.local/bin/golangci-lint.exe`。archive 內部路徑含版本字串，須與 url 用同一個 `$ver` 變數 inject。

#### Scenario: Windows 上下載 golangci-lint binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 下載 `golangci-lint-<version>-windows-amd64.zip`，抽出 `golangci-lint-<version>-windows-amd64/golangci-lint.exe` 至 `~/.local/bin/`，設為 executable

#### Scenario: Windows 上 golangci-lint 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "golangci-lint"`

### Requirement: Wave 2 一次性遷移腳本
`run_once_after_migrate-scoop-wave2.ps1.tmpl` SHALL 在 Windows 上執行一次性遷移：卸載已存在的 scoop kubectl/kubelogin/yt-dlp/hugo/hugo-extended/nexttrace/golangci-lint。腳本 SHALL 為冪等：scoop 未安裝對應套件時視為 no-op。

腳本 SHALL NOT 動 User PATH（Wave 1 的 `run_once_after_migrate-scoop-to-external.ps1.tmpl` 已把 `~/.local/bin` 排在 `~/scoop/shims` 之前）。

#### Scenario: 已安裝 scoop 套件被卸載
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報已安裝
- **THEN** 腳本執行 `scoop uninstall <pkg>`，scoop apps 目錄該套件被移除

#### Scenario: scoop 套件未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報未安裝
- **THEN** 腳本不執行 `scoop uninstall`，繼續處理下一個

#### Scenario: User PATH 不被本腳本修改
- **WHEN** Wave 2 migration 腳本執行
- **THEN** User PATH 環境變數值維持不變（PATH 排序為 Wave 1 migration 腳本的責任）

### Requirement: SSH workaround 檔案於 Wave 1 後移除
`Documents/exact__shared-profile.d/35-scoop-ssh-shims.ps1` SHALL 在 Wave 1 完成後從 chezmoi source 移除；同時 `90-prompt.ps1` 中 starship 的 shim-bypass 邏輯 SHALL 簡化為標準的 `starship init powershell` 呼叫。

#### Scenario: 35-scoop-ssh-shims.ps1 不再存在於 source
- **WHEN** chezmoi apply 執行
- **THEN** target `~/Documents/PowerShell/_shared-profile.d/35-scoop-ssh-shims.ps1` 不存在（chezmoi 因 source 已移除而清理 target）

#### Scenario: 90-prompt.ps1 starship 啟動使用標準寫法
- **WHEN** PowerShell session 載入 `90-prompt.ps1`
- **THEN** 透過 `Get-Command starship` 解析（會走 PATH，命中 `~/.local/bin/starship.exe`），呼叫 `starship init powershell --print-full-init` 並 `Invoke-Expression`，不再有 shim 路徑字串替換邏輯

#### Scenario: 90-prompt.ps1 保留 OSC 9;9 directory tracking
- **WHEN** PowerShell session 載入 `90-prompt.ps1`
- **THEN** `Invoke-Starship-PreCommand` 函式仍被定義，OSC 9;12/9;9 escape sequence 仍輸出，Windows Terminal duplicate-pane 仍能繼承目錄

### Requirement: gopass 在 Windows 上由 chezmoi-external 安裝
Windows 上 gopass SHALL 由 `.chezmoiexternal.toml` 下載 GitHub Release `gopasspw/gopass` 的 `gopass-<version>-windows-amd64.zip`，抽出 archive 根目錄的 `gopass.exe` 至 `~/.local/bin/gopass.exe`。版本以 `$gopassVersion` 變數 pinned；URL 中的 tag 帶 `v` prefix，archive 內檔名版本字串不帶 `v`，須以同一變數雙重 inject。

#### Scenario: Windows 上下載 gopass binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 `https://github.com/gopasspw/gopass/releases/download/v<version>/gopass-<version>-windows-amd64.zip` 下載並抽出 `gopass.exe` 至 `~/.local/bin/gopass.exe`，設為 executable

#### Scenario: Windows 上 gopass 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "gopass"`

### Requirement: curl 不再由 dotfiles 安裝
Windows 上 dotfiles SHALL NOT 透過 scoop 安裝 curl。`curl.exe` 仰賴 Win10 build 17063+ 內建於 `C:\Windows\System32\curl.exe`，以及 Git for Windows 安裝時自帶於 `<git>\mingw64\bin\curl.exe`。dotfiles 不再保證 scoop 版本可用。

#### Scenario: Windows 上 curl 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "curl"`

#### Scenario: Linux/macOS curl 安裝不受影響
- **WHEN** 在 Linux 或 macOS 上的 `run_once_install-cli-tools.sh.tmpl` 執行
- **THEN** 該腳本仍可使用 apt/brew 安裝 curl（本 requirement 限定 Windows scope）

### Requirement: wget 不再由 dotfiles 在 Windows 上安裝
Windows 上 dotfiles SHALL NOT 透過 scoop 安裝 wget。Windows PowerShell / Git Bash 流程內部不呼叫 wget；`run_onchange_install-03-claude-config.sh.tmpl` 的 `curl || wget` fallback 為 `.sh.tmpl`（Linux/macOS only）。如使用者個人需要 wget 可手動安裝。

#### Scenario: Windows 上 wget 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "wget"`

#### Scenario: Linux/macOS wget 安裝不受影響
- **WHEN** 在 Linux 或 macOS 上的 `run_once_install-cli-tools.sh.tmpl` 執行
- **THEN** 該腳本仍可使用 apt/brew 安裝 wget（本 requirement 限定 Windows scope）

### Requirement: Wave 3 一次性遷移腳本
`run_once_after_migrate-scoop-wave3.ps1.tmpl` SHALL 在 Windows 上執行一次性遷移：卸載 3 個 scoop 套件：`gopass`、`curl`、`wget`（無論是 dotfiles 安裝還是使用者手動安裝皆會卸載）。腳本 SHALL 為冪等：scoop 未安裝對應套件時視為 no-op；scoop 未安裝時整支 skip。

腳本 SHALL NOT 動 User PATH（Wave 1 的 `run_once_after_migrate-scoop-to-external.ps1.tmpl` 已把 `~/.local/bin` 排在 `~/scoop/shims` 之前）。

#### Scenario: 已安裝 scoop 套件被卸載
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報已安裝
- **THEN** 腳本執行 `scoop uninstall <pkg>`，scoop apps 目錄該套件被移除

#### Scenario: scoop 套件未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報未安裝
- **THEN** 腳本不執行 `scoop uninstall`，繼續處理下一個

#### Scenario: scoop 未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `Get-Command scoop` 回 not found
- **THEN** 腳本印警告訊息並 return，不嘗試任何 scoop 命令

#### Scenario: User PATH 不被本腳本修改
- **WHEN** Wave 3 migration 腳本執行
- **THEN** User PATH 環境變數值維持不變（PATH 排序為 Wave 1 migration 腳本的責任）

### Requirement: clink 不再由 dotfiles 安裝
Windows 上 dotfiles SHALL NOT 透過 scoop 安裝 `clink`。dotfiles 內無任何流程呼叫 `clink autorun install`，且 starship 已透過 PowerShell/Git Bash/zsh init 取代 cmd.exe 命令列增強需求。

#### Scenario: Windows 上 clink 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "clink"`

### Requirement: dark 不再由 dotfiles 安裝（軟脫管）
Windows 上 dotfiles SHALL NOT 透過 scoop 主動安裝 `dark`（WiX Toolset Decompiler）。`dark.exe` 在 dotfiles 全 repo 無任何引用，已安裝的 scoop manifest 亦無宣告為 dependency。**現有已安裝的 dark 不主動卸載**（軟脫管）。

#### Scenario: Windows 上 dark 不再經由 Scoop 安裝
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "dark"`

#### Scenario: 既有 dark 安裝不被本變更卸載
- **WHEN** chezmoi apply 在 Windows 執行且 `scoop list dark` 回報已安裝
- **THEN** Wave 4 migration 腳本 SHALL NOT 執行 `scoop uninstall dark`

### Requirement: vimtutor 不再由 dotfiles 安裝（軟脫管）
Windows 上 dotfiles SHALL NOT 透過 scoop 主動安裝 `vimtutor`。它為互動式教學程式，無腳本依賴。**現有已安裝的 vimtutor 不主動卸載**（軟脫管）。

#### Scenario: Windows 上 vimtutor 不再經由 Scoop 安裝
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 包含 vimtutor 安裝區塊

#### Scenario: 既有 vimtutor 安裝不被本變更卸載
- **WHEN** chezmoi apply 在 Windows 執行且 `scoop list vimtutor` 回報已安裝
- **THEN** Wave 4 migration 腳本 SHALL NOT 執行 `scoop uninstall vimtutor`

### Requirement: winget 不再由 dotfiles 安裝
Windows 上 dotfiles SHALL NOT 透過 scoop 安裝 `winget`。Win10 build 1809+ 與 Win11 已 OS-bundled `winget.exe` 於 `%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe`（透過 Microsoft.DesktopAppInstaller Store package），scoop shim 為冗餘來源。

#### Scenario: Windows 上 winget 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "winget"`

#### Scenario: OS-bundled winget 接手
- **WHEN** 使用者於 PowerShell 執行 `winget --version`
- **THEN** PATH lookup 命中 `%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe`，命令正常執行

### Requirement: winget-ps 不再由 dotfiles 安裝
Windows 上 dotfiles SHALL NOT 透過 scoop 安裝 `winget-ps`（`Microsoft.WinGet.Client` PowerShell 模組）。dotfiles 內無任何 PowerShell script 載入此模組或呼叫其 cmdlet（`Find-WinGetPackage` / `Install-WinGetPackage` 等）。

#### Scenario: Windows 上 winget-ps 不再經由 Scoop 安裝
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl` 執行
- **THEN** 該腳本 SHALL NOT 包含 winget-ps 安裝區塊

#### Scenario: PowerToys CommandNotFound 模組不受影響
- **WHEN** 使用者啟動 PowerShell 且已安裝 PowerToys CommandNotFound 模組
- **THEN** `Microsoft.WinGet.CommandNotFound` 仍可正常載入（該模組獨立於 `Microsoft.WinGet.Client`/winget-ps）並透過 OS-bundled winget 提供建議

### Requirement: Wave 4 一次性遷移腳本
`run_once_after_migrate-scoop-wave4.ps1.tmpl` SHALL 在 Windows 上執行一次性遷移：卸載 3 個 scoop 套件 `clink`、`winget`、`winget-ps`。腳本 SHALL 為冪等：scoop 未安裝對應套件時視為 no-op；scoop 未安裝時整支 skip。

腳本 SHALL NOT 卸載 `dark` 與 `vimtutor`（軟脫管項目）。

腳本 SHALL NOT 動 User PATH（Wave 1 的 `run_once_after_migrate-scoop-to-external.ps1.tmpl` 已把 `~/.local/bin` 排在 `~/scoop/shims` 之前）。

#### Scenario: 已安裝 scoop 硬清套件被卸載
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報已安裝（pkg ∈ {clink, winget, winget-ps}）
- **THEN** 腳本執行 `scoop uninstall <pkg>`，scoop apps 目錄該套件被移除

#### Scenario: 軟脫管套件不被卸載
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** 腳本 SHALL NOT 嘗試 `scoop uninstall dark` 或 `scoop uninstall vimtutor`，無論其安裝狀態

#### Scenario: scoop 硬清套件未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報未安裝
- **THEN** 腳本不執行 `scoop uninstall`，繼續處理下一個

#### Scenario: scoop 未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `Get-Command scoop` 回 not found
- **THEN** 腳本印警告訊息並 return，不嘗試任何 scoop 命令

#### Scenario: User PATH 不被本腳本修改
- **WHEN** Wave 4 migration 腳本執行
- **THEN** User PATH 環境變數值維持不變（PATH 排序為 Wave 1 migration 腳本的責任）

### Requirement: PowerShell command-not-found 前置條件明示
所有 `Documents/{Windows,}PowerShell/profile.d/99-command-not-found.ps1` 檔案 SHALL 在檔案頂部包含 header comment 明示前置條件。實際命令邏輯不變。

兩個版本對應不同 PowerShell：
- `Documents/PowerShell/profile.d/99-command-not-found.ps1`（PowerShell 7+）依賴 PowerToys 安裝並啟用 `Microsoft.WinGet.CommandNotFound` 模組，以及 OS-bundled `winget.exe`（Win10 1809+/Win11）。仍以 `-ErrorAction SilentlyContinue` 確保 silent no-op。
- `Documents/WindowsPowerShell/profile.d/99-command-not-found.ps1`（Windows PowerShell 5.x）直接呼叫 `winget search`，依賴 OS-bundled `winget.exe`。

#### Scenario: PS7 檔案 header 註明前置條件
- **WHEN** 開啟 `Documents/PowerShell/profile.d/99-command-not-found.ps1`
- **THEN** 檔案前段包含 comment 提及 PowerToys CommandNotFound 模組與 OS-bundled winget 兩項前置條件

#### Scenario: PS5 檔案 header 註明前置條件
- **WHEN** 開啟 `Documents/WindowsPowerShell/profile.d/99-command-not-found.ps1`
- **THEN** 檔案前段包含 comment 提及 OS-bundled winget 前置條件

#### Scenario: Import-Module 與 CommandNotFoundAction 邏輯保持不變
- **WHEN** PowerShell session 啟動載入對應 .ps1
- **THEN** PS7 仍執行 `Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction SilentlyContinue`；PS5 仍註冊 `$ExecutionContext.InvokeCommand.CommandNotFoundAction`，無其他副作用

### Requirement: docker CLI 在 Windows 上由 chezmoi-external 安裝
Windows 上 docker CLI SHALL 由 `.chezmoiexternal.toml` 從 Docker Inc. 官方靜態映像 `https://download.docker.com/win/static/stable/x86_64/docker-<version>.zip` 下載，僅抽出 archive 內 `docker/docker.exe` 至 `~/.local/bin/docker.exe`，捨棄同 archive 的 `dockerd.exe`。版本以 `$dockerVersion` 變數 pinned。

URL pattern 與 Wave 1~3 的 GitHub release 不同，是 Wave 5 首見的 `download.docker.com` 路徑（Docker Inc. 官方 CDN）。

#### Scenario: Windows 上下載 docker.exe
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 `https://download.docker.com/win/static/stable/x86_64/docker-<version>.zip` 下載並抽出 `docker/docker.exe` 至 `~/.local/bin/docker.exe`，設為 executable

#### Scenario: dockerd.exe 不會出現在 ~/.local/bin
- **WHEN** chezmoi apply 完成 Wave 5 階段
- **THEN** `~/.local/bin/dockerd.exe` 不存在（archive 中的 `dockerd.exe` 因 `path` 過濾未抽出）

#### Scenario: Windows 上 docker 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-containers.ps1.tmpl`（或其他 install 腳本）執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "docker"`

### Requirement: docker-compose 在 Windows 上由 chezmoi-external 安裝
Windows 上 docker-compose SHALL 由 `.chezmoiexternal.toml` 從 GitHub Release `docker/compose` 直接下載 `docker-compose-windows-x86_64.exe`（裸 binary，無 archive）至 `~/.local/bin/docker-compose.exe`。版本以 `$dockerComposeVersion` 變數 pinned；URL tag 帶 `v` prefix。

#### Scenario: Windows 上下載 docker-compose.exe
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 從 `https://github.com/docker/compose/releases/download/v<version>/docker-compose-windows-x86_64.exe` 下載至 `~/.local/bin/docker-compose.exe`，設為 executable

#### Scenario: Windows 上 docker-compose 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-containers.ps1.tmpl`（或其他 install 腳本）執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "docker-compose"`

### Requirement: DOCKER_HOST env var 由 dotfiles 管理（Windows User scope）
Windows 上 SHALL 存在 `run_onchange_before_set-docker-host.ps1.tmpl`，在 chezmoi apply 的 `run_before_` 階段執行，職責為：確保 User-scope 環境變數 `DOCKER_HOST` 的值為 `tcp://127.0.0.1:2375`。

腳本 SHALL 為冪等：值已正確時 SHALL NOT 再次寫入。

腳本 SHALL 為 Windows-only，透過 chezmoi template `{{ if eq .chezmoi.os "windows" }}` 守衛。

腳本 SHALL 假設「個人開發機、單一架構」場景，**不**支援跳板機、CI runner、多 host 切換等情境。

#### Scenario: Fresh machine 上 DOCKER_HOST 不存在
- **WHEN** Windows 機器上 User env var `DOCKER_HOST` 為 null 或空字串，chezmoi apply 執行至 `run_before_` 階段
- **THEN** 腳本透過 `[Environment]::SetEnvironmentVariable("DOCKER_HOST", "tcp://127.0.0.1:2375", "User")` 寫入，並印出提示要求重開 session 讓變更生效

#### Scenario: DOCKER_HOST 已是正確值時 no-op
- **WHEN** Windows 機器上 User env var `DOCKER_HOST` 已等於 `tcp://127.0.0.1:2375`，chezmoi apply 執行
- **THEN** 腳本不重新寫入，不印出 setx 訊息（可印 "already set" gray 訊息）

#### Scenario: DOCKER_HOST 被使用者改成其他值時被覆寫
- **WHEN** Windows 機器上 User env var `DOCKER_HOST` 被使用者改為其他值（例如 `tcp://remote-host:2375`），chezmoi apply 執行
- **THEN** 腳本將 `DOCKER_HOST` 覆寫回 `tcp://127.0.0.1:2375`，印出 warning 註明值被回正

### Requirement: Wave 5 一次性遷移腳本
`run_once_after_migrate-scoop-wave5.ps1.tmpl` SHALL 在 Windows 上執行一次性遷移：卸載 2 個 scoop 套件 `docker`、`docker-compose`。腳本 SHALL 為冪等：scoop 未安裝對應套件時視為 no-op；scoop 未安裝時整支 skip。

腳本 SHALL NOT 卸載 `lazydocker`（依 user 指示保持 scoop 安裝，不受 chezmoi 控管）。

腳本 SHALL NOT 動 User PATH（Wave 1 的 `run_once_after_migrate-scoop-to-external.ps1.tmpl` 已把 `~/.local/bin` 排在 `~/scoop/shims` 之前）。

#### Scenario: 已安裝 scoop 硬清套件被卸載
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報已安裝（pkg ∈ {docker, docker-compose}）
- **THEN** 腳本執行 `scoop uninstall <pkg>`，scoop apps 目錄該套件被移除

#### Scenario: lazydocker 不被卸載
- **WHEN** chezmoi apply 在 Windows 執行且 `scoop list lazydocker` 回報已安裝
- **THEN** Wave 5 migration 腳本 SHALL NOT 執行 `scoop uninstall lazydocker`

#### Scenario: scoop 硬清套件未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報未安裝
- **THEN** 腳本不執行 `scoop uninstall`，繼續處理下一個

#### Scenario: scoop 未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `Get-Command scoop` 回 not found
- **THEN** 腳本印警告訊息並 return，不嘗試任何 scoop 命令

#### Scenario: User PATH 不被本腳本修改
- **WHEN** Wave 5 migration 腳本執行
- **THEN** User PATH 環境變數值維持不變（PATH 排序為 Wave 1 migration 腳本的責任）

### Requirement: ffmpeg 套件在 Windows 上由 chezmoi-external 安裝
Windows 上 ffmpeg 套件（`ffmpeg.exe` + `ffprobe.exe` + `ffplay.exe` 三隻 binary）SHALL 由 `.chezmoiexternal.toml` 從 `BtbN/FFmpeg-Builds` GitHub Release 下載 `n8.1` stable channel static GPL build 的 zip，以 `type = "archive-file"` × 3 entries 共用同一 URL，分別以 `path` 過濾抽出三隻 binary 至 `~/.local/bin/`，並設為 executable。

版本以兩個 chezmoi template 變數 pinning：`$ffmpegTag`（BtbN dated autobuild tag，如 `autobuild-2026-05-24-13-16`）與 `$ffmpegAsset`（含 git-describe 後綴的 asset filename，如 `ffmpeg-n8.1.1-8-gb21e00eda5-win64-gpl-8.1.zip`），URL 形式：`https://github.com/BtbN/FFmpeg-Builds/releases/download/{{ $ffmpegTag }}/{{ $ffmpegAsset }}`。

URL pattern 與 Wave 1~3 的 GitHub release 雷同（同樣 github.com/<repo>/releases/download/），但 asset filename 含 BtbN 特殊的 git-describe 後綴，且 dated tag 與 `latest` rolling tag 的 asset 命名格式完全不同。

#### Scenario: Windows 上下載 ffmpeg 套件三隻 binary
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 自 `https://github.com/BtbN/FFmpeg-Builds/releases/download/<tag>/<asset>.zip` 下載並抽出 `ffmpeg.exe`、`ffprobe.exe`、`ffplay.exe` 至 `~/.local/bin/`，三隻皆設為 executable

#### Scenario: dated tag pinning 確保版本 reproducible
- **WHEN** 同一 commit 在不同機器、不同時間執行 chezmoi apply
- **THEN** 三隻 binary 的版本字串（`ffmpeg -version` 輸出）一致——pinning 採 BtbN dated tag + 含 git-describe 後綴的 asset filename，**不**使用 rolling `latest` tag

#### Scenario: Windows 上 ffmpeg 不再經由 Scoop
- **WHEN** 在 Windows 上的 `run_once_install-cli-tools.ps1.tmpl`（或其他 install 腳本）執行
- **THEN** 該腳本 SHALL NOT 呼叫 `Install-ScoopPackage "ffmpeg"`

### Requirement: Wave 6 一次性遷移腳本
`run_once_after_migrate-scoop-wave6.ps1.tmpl` SHALL 在 Windows 上執行一次性遷移：卸載 1 個 scoop 套件 `ffmpeg`。腳本 SHALL 為冪等：scoop 未安裝對應套件時視為 no-op；scoop 未安裝時整支 skip。

腳本 SHALL NOT 動 User PATH（Wave 1 的 `run_once_after_migrate-scoop-to-external.ps1.tmpl` 已把 `~/.local/bin` 排在 `~/scoop/shims` 之前）。

#### Scenario: 已安裝 scoop ffmpeg 被卸載
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list ffmpeg` 回報已安裝
- **THEN** 腳本執行 `scoop uninstall ffmpeg`，scoop apps 目錄該套件被移除

#### Scenario: scoop ffmpeg 未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list ffmpeg` 回報未安裝
- **THEN** 腳本不執行 `scoop uninstall`，繼續結束

#### Scenario: scoop 未安裝時整支 skip
- **WHEN** chezmoi apply 在 Windows 執行，且 `Get-Command scoop` 回 not found
- **THEN** 腳本印警告訊息並 return，不嘗試任何 scoop 命令

#### Scenario: User PATH 不被本腳本修改
- **WHEN** Wave 6 migration 腳本執行
- **THEN** User PATH 環境變數值維持不變（PATH 排序為 Wave 1 migration 腳本的責任）

### Requirement: vim 套件本體在 Windows 上由 chezmoi-external 整包安裝
Windows 上 vim 套件（vim distribution + 4 個依賴 DLL + 完整 runtime/ 子目錄）SHALL 由 `.chezmoiexternal.toml` 從 `vim/vim-win32-installer` GitHub Release 下載 `gvim_<version>_x64.zip`（unsigned 變體），以 `type = "archive"` + `stripComponents = 1` 整包解壓至 `~/.local/share/vim/`，產生 `~/.local/share/vim/vim92/` 子樹（含 `vim.exe`、`gvim.exe`、`xxd.exe`、`vim64.dll`、`libiconv-2.dll`、`libintl-8.dll`、`libsodium.dll` 與 `autoload/`、`syntax/`、`doc/`、`tutor/` 等 runtime 子目錄）。

版本以 chezmoi template 變數 `$vimVersion` pinning（如 `9.2.0530`），URL 形式：`https://github.com/vim/vim-win32-installer/releases/download/v{{ $vimVersion }}/gvim_{{ $vimVersion }}_x64.zip`。

#### Scenario: Windows 上下載並整包解壓 vim distribution
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 自 `https://github.com/vim/vim-win32-installer/releases/download/v<version>/gvim_<version>_x64.zip` 下載並解壓至 `~/.local/share/vim/`，最終 `~/.local/share/vim/vim92/vim.exe` 存在且可執行

#### Scenario: 版本 pinning 確保跨機器 reproducible
- **WHEN** 同一 commit 在不同機器、不同時間執行 chezmoi apply
- **THEN** `~/.local/share/vim/vim92/vim.exe --version` 輸出的版本字串一致——pinning 採 `$vimVersion` 變數，**不**使用 rolling `latest` tag

#### Scenario: runtime 資源完整可用
- **WHEN** 使用者執行 `vim foo.py`
- **THEN** vim 能正確載入 Python syntax highlighting（驗證 `~/.local/share/vim/vim92/syntax/python.vim` 存在且 vim runtime path 解析成功）

### Requirement: 15 個 .cmd wrapper 鏡像 scoop bin 介面
`~/.local/bin/` SHALL 包含 15 個純 ASCII `.cmd` wrapper 檔，每個 wrapper 對應 scoop `vim.json` manifest 的 `bin[]` 陣列中對應 alias，呼叫對應的 underlying `.exe` 並傳入正確 flag。Wrapper 全部以靜態文字（非 chezmoi template）寫成，內嵌路徑為 `%USERPROFILE%\.local\share\vim\vim92\<binary>.exe`。

Flag 對應表：
- `vim.cmd` / `vi.cmd` → `vim.exe`（無 flag）
- `ex.cmd` → `vim.exe -e`
- `view.cmd` → `vim.exe -R`
- `rvim.cmd` → `vim.exe -Z`
- `rview.cmd` → `vim.exe -RZ`
- `vimdiff.cmd` → `vim.exe -d`
- `gvim.cmd` → `gvim.exe`（無 flag）
- `gview.cmd` → `gvim.exe -R`
- `evim.cmd` → `gvim.exe -y`
- `eview.cmd` → `gvim.exe -Ry`
- `rgvim.cmd` → `gvim.exe -Z`
- `rgview.cmd` → `gvim.exe -RZ`
- `gvimdiff.cmd` → `gvim.exe -d`
- `xxd.cmd` → `xxd.exe`（無 flag）

#### Scenario: 直接呼叫 vim/gvim/xxd 走 wrapper
- **WHEN** 使用者在 PowerShell / cmd.exe / Git Bash 執行 `vim foo.txt`
- **THEN** `where.exe vim` 解析到 `~/.local/bin/vim.cmd`，wrapper 轉發到 `~/.local/share/vim/vim92/vim.exe`，foo.txt 被開啟

#### Scenario: alias mode wrapper 傳遞正確 flag
- **WHEN** 使用者執行 `vimdiff a.txt b.txt`
- **THEN** `~/.local/bin/vimdiff.cmd` 被呼叫，wrapper 執行 `vim.exe -d a.txt b.txt`，vim 進入 diff 模式

#### Scenario: gvim alias mode wrapper 傳遞正確 flag
- **WHEN** 使用者執行 `evim foo.txt`
- **THEN** `~/.local/bin/evim.cmd` 被呼叫，wrapper 執行 `gvim.exe -y foo.txt`，gvim 進入 easy mode

### Requirement: Windows 上 vim 不再經由 Scoop
`run_once_install-cli-tools.ps1.tmpl`（或其他 install 腳本）SHALL NOT 呼叫 `Install-ScoopPackage "vim"`。腳本可保留註解標明 vim 已遷至 `.chezmoiexternal.toml`，指引讀者去看 `run_once_after_migrate-scoop-wave7.ps1.tmpl`。

#### Scenario: install script 不主動安裝 scoop vim
- **WHEN** 在乾淨 Windows 上首次 `chezmoi apply`
- **THEN** `run_once_install-cli-tools.ps1.tmpl` 不執行 `scoop install vim`；vim 由 `.chezmoiexternal.toml` 提供

### Requirement: Wave 7 一次性遷移腳本
`run_once_after_migrate-scoop-wave7.ps1.tmpl` SHALL 在 Windows 上執行一次性遷移：卸載 1 個 scoop 套件 `vim`。腳本 SHALL 為冪等：scoop 未安裝 vim 時視為 no-op；scoop 未安裝時整支 skip。

腳本 SHALL NOT 動 User PATH（Wave 1 的 `run_once_after_migrate-scoop-to-external.ps1.tmpl` 已把 `~/.local/bin` 排在 `~/scoop/shims` 之前）。

腳本 SHALL NOT 主動清理 gvim 右鍵選單 registry 項目（屬於 Windows shell 整合層而非本 wave 範圍；使用者需要時可手動）。

#### Scenario: 已安裝 scoop vim 被卸載
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list vim` 回報已安裝
- **THEN** 腳本執行 `scoop uninstall vim`，scoop apps 目錄該套件被移除

#### Scenario: scoop vim 未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list vim` 回報未安裝
- **THEN** 腳本不執行 `scoop uninstall`，繼續結束

#### Scenario: scoop 未安裝時整支 skip
- **WHEN** chezmoi apply 在 Windows 執行，且 `Get-Command scoop` 回 not found
- **THEN** 腳本印警告訊息並 return，不嘗試任何 scoop 命令

#### Scenario: User PATH 不被本腳本修改
- **WHEN** Wave 7 migration 腳本執行
- **THEN** User PATH 環境變數值維持不變（PATH 排序為 Wave 1 migration 腳本的責任）

