## Why

承 Wave 1~6 的 scoop → chezmoi-external 系列，Category A archive-pattern 還剩 vim / nvm-windows / gpg 三個。vim 是 Wave 6 ffmpeg 之後的下一步——複雜度比 ffmpeg 高一階（多 binary + DLL + runtime/ 目錄）但比 gpg 低一階（無 corp-ssh-askpass 依賴、無 NSIS installer side-effects），是「驗證 `type = "archive"` 完整封包模式」最合適的下手目標。Wave 7 確立的「archive + .cmd wrapper」樣板，後續 nvm-windows 即可複用。

## What Changes

**chezmoi-external 新條目（Windows-only）**：
- `~/.local/share/vim/vim92/`：從 `vim/vim-win32-installer` GitHub Release 下載 `gvim_<version>_x64.zip`（unsigned，與 scoop 預設一致），以 `type = "archive"` + `stripComponents = 1` 整包解到 `~/.local/share/vim/`，產生 `~/.local/share/vim/vim92/{vim,gvim,xxd,vimrun,...}.exe` + 4 個 DLL + 完整 runtime 子目錄（autoload/、syntax/、doc/、tutor/ 等共 2669 檔 / 56 MB）。版本以 `$vimVersion` chezmoi template 變數 pinning（reproducible，與 Wave 1-6 一致）。

**Bin wrappers（Windows-only，新增 15 個 `.cmd` 檔）**：
- `~/.local/bin/{vim,vi,ex,view,rvim,rview,vimdiff}.cmd` 七支：對應 `vim.exe`（含對應 flag）。
- `~/.local/bin/{gvim,gview,evim,eview,rgvim,rgview,gvimdiff}.cmd` 七支：對應 `gvim.exe`（含對應 flag）。
- `~/.local/bin/xxd.cmd`：對應 `xxd.exe`。
- Flag 對應表 100% 鏡像 scoop manifest 的 `bin[]` 陣列（見 design.md D2）；wrappers 為純 static `.cmd`，不走 chezmoi template，因 `vim92` runtime 目錄名稱僅 vim minor version bump 時變動（9.2.x patch 升級不影響）。

**Install script 註解**：
- `run_once_install-cli-tools.ps1.tmpl` 從未呼叫 `Install-ScoopPackage "vim"`（與 ffmpeg 同情況）。本提案僅在 `# ── Vim tutor ──` 區段現有 vimtutor 註解之下追加一行說明：「vim 套件本身於 Wave 7 (2026-05-25) 由 chezmoi-external 接手」，指向 migration 腳本。

**Active migration on existing machines**：
- 新增 `run_once_after_migrate-scoop-wave7.ps1.tmpl`：`scoop uninstall vim` 若已安裝（冪等；scoop 未安裝時整支 skip）。
- **不**動 User PATH（Wave 1 已搞定 `~/.local/bin` ordering）。

**Source-of-truth 補洞**：
- `scoop/scoopfile.json` 從一開始就無 `vim` 記錄（跟 ffmpeg、docker 同類型的歷史 drift）。本提案**不**修補此 drift（會擴大範圍），僅留下記錄。

**不動**：
- macOS / Linux 安裝（brew / apt 提供原生 `vim` 套件）。Wave 1-6 一貫只動 Windows scoop。
- 既有 Wave 1+2+3+5+6 entries、migration 腳本、PATH 設定。
- gvim 的 Windows shell 右鍵選單註冊（scoop manifest 的 `install-context.reg` post-install）——本身屬於 Windows 整合層而非 vim binary 本體，超出本 wave 範圍；如有需要由使用者手動執行。

**Breaking changes**：
- 既有 Windows 機器執行 `chezmoi apply` 後，scoop `vim` 會被卸載。`~/.local/bin/{vim,gvim,xxd,...}.cmd` 接手；因 Wave 1 已把 `~/.local/bin` 排在 `~/scoop/shims` 之前，PATH lookup 自動命中 wrapper（再轉發到 `~/.local/share/vim/vim92/*.exe`）。
- gvim 右鍵選單若先前由 scoop post-install 註冊，於 scoop uninstall 後失效——非本 wave 規格內，使用者若需要可手動跑 `~/.local/share/vim/vim92/install-context.reg`（檔仍存在）。

## Capabilities

### New Capabilities
（無）

### Modified Capabilities
- `tool-dependencies`：新增 4 條 requirement——vim 套件 archive 整包安裝；15 個 `.cmd` wrapper 鏡像 scoop bin 介面；Windows install script 不再經由 Scoop 安裝 vim；Wave 7 一次性遷移腳本。

## Impact

**Code changes**：
- `.chezmoiexternal.toml`：新增 Wave 7 區塊，含 1 條 `archive` external entry 與 pinned `$vimVersion` 變數。
- `dot_local/bin/`：新增 15 個 `.cmd` wrapper 檔（純 ASCII、無 BOM 需求）。
- `run_once_install-cli-tools.ps1.tmpl`：於 `# ── Vim tutor ──` 區段追加註解標明 vim 本體於 Wave 7 由 chezmoi-external 接手。
- `run_once_after_migrate-scoop-wave7.ps1.tmpl`（新檔）：Windows-only，冪等 scoop uninstall vim。

**Existing machine state changes**：
- Scoop 卸載 1 個套件（`vim`）。
- `~/.local/share/vim/vim92/` 出現（~56 MB 解壓）。
- `~/.local/bin/{15 wrappers}.cmd` 出現；後續 `vim`、`gvim`、`vimdiff` 等命令解析到 wrapper 再轉發。
- User PATH **不變**。

**Memory updates（在 archive step 處理）**：
- `reference_chezmoi_external_cli_tools.md`：新增 Wave 7 區塊，記錄 vim archive-mode 設計、15 個 wrapper 對應 scoop bin 表、版本 bump 時需同步更新 wrappers 中 `vim92` 路徑（minor version 升級時）。
- `project_scoop_external_wave4_candidates.md`：Category A 表格將 vim 劃掉，標記 Wave 7 完成；補一段「archive-pattern 第二案的擴充——`type = "archive"` 整包 + `.cmd` wrappers」結論供後續 nvm/gpg 參考。
- 視需要更新 `MEMORY.md` 索引。

**Out of scope（後續 Wave 候選）**：
- **archive-pattern 剩餘**：nvm-windows（NVM_HOME/NVM_SYMLINK env vars + junction 機制）、gpg（corp-ssh-askpass 核心依賴 + gnupg.org NSIS 非 GitHub 來源）。
- **多版本 toolchain**：Category D（python/jdk/go/rustup/mvn）。
- **macOS/Linux vim 統一管理**：brew/apt 已提供原生套件管理，無遷移需求。
- **gvim 右鍵選單註冊**：scoop post-install 的 `install-context.reg`；屬於 Windows shell 整合而非 binary 本體，超出本 wave 範圍。
- **vimtutor 安裝**：Wave 4 已從 dotfiles 移除（interactive tutorial 無腳本依賴），本 wave 維持現狀。
