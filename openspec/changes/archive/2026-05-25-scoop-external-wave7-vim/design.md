## Context

承 Wave 1~6 將 scoop-managed CLI 遷至 `.chezmoiexternal.toml` 的工程脈絡。Wave 7 範圍由 user 決定，啟動 Category A archive-pattern 系列的第二個工具 vim。設計重點：

- **第一個「真正的應用程式封包」**：Wave 1-5 都是單一 static binary（starship / kubectl / docker.exe 等），Wave 6 ffmpeg 雖然 3 隻但全部是 static、無 runtime data。vim 是第一個帶有 **DLL 依賴 + runtime/ 資源樹** 的工具——`vim.exe` (209KB) 需要 `vim64.dll` (5.6MB) + `libiconv-2.dll` / `libintl-8.dll` / `libsodium.dll` 共存同目錄；且 vim 啟動時需要 `autoload/`、`syntax/`、`doc/`、`tutor/` 等 2000+ 檔的 runtime data 才能正常工作。
- **15 binary alias 全部來自 3 個真實 exe**：scoop 為 vim 建立 15 個 shim 對應 vim 的 15 種模式（vi / ex / view / rvim / rview / vimdiff / gvim / gview / evim / eview / rgvim / rgview / gvimdiff / xxd / vim），但實際 .exe 檔只有 3 個：`vim.exe`、`gvim.exe`、`xxd.exe`。alias 透過命令名觸發不同 flag（例如 `vimdiff` = `vim -d`、`evim` = `gvim -y`）。
- **無 corp-ssh-askpass 依賴 / 無 env var 需求**：跟 Wave 6 ffmpeg 一樣，vim 純粹是 editor CLI，不影響 SSH 工作流，無 env var 需設定。範圍比後續 nvm/gpg 乾淨。
- **vim runtime dir 命名綁版本**：vim 9.2.x patch release 共用 `vim92/` 目錄；vim 9.3 升上來會變 `vim93/`。Wrapper 路徑中的 `vim92` 字串需於 minor version bump 時手動同步——這是本 wave 設計的主要技術債（見 D2 / Risks）。

## Goals / Non-Goals

**Goals:**
- `~/.local/share/vim/vim92/` 由 `.chezmoiexternal.toml` 從 `vim/vim-win32-installer` GitHub Release 整包下載並解壓，version pinning 至明確 `$vimVersion` 變數（reproducible across machines & time）。
- `~/.local/bin/{vim,vi,ex,view,rvim,rview,vimdiff,gvim,gview,evim,eview,rgvim,rgview,gvimdiff,xxd}.cmd` 共 15 個 wrapper 鏡像 scoop bin manifest 的 flag 對應，使既有使用模式無 break。
- 既有 scoop `vim` 被 `run_once_after_migrate-scoop-wave7.ps1.tmpl` 卸載。
- 變更後 `vim --version`、`gvim --version`、`xxd -v`、`vi -h`、`vimdiff` 等命令行為與遷移前一致（含 alias mode 開關）。
- 為後續 nvm-windows 留下可複用的「archive + .cmd wrapper」reference 結構。

**Non-Goals:**
- **不**動 macOS / Linux 安裝（brew / apt 已提供原生 vim 套件管理，無遷移需求）。
- **不**追求自動跟最新版（reproducibility 優先；版本升級需 explicit PR）。
- **不**用 signed 變體（與 scoop 預設一致；個人開發機無 EDR/AppLocker 通行要求）。
- **不**修補 `scoop/scoopfile.json` 缺漏 vim 紀錄的 drift（既存歷史問題，超出本 wave 範圍；與 Wave 5 D6、Wave 6 D4 一致）。
- **不**註冊 gvim 右鍵選單（scoop post-install 的 `install-context.reg`）——屬於 Windows shell 整合層而非 binary 本體，需要時使用者手動執行 `~/.local/share/vim/vim92/install-context.reg`。
- **不**處理 vimtutor（Wave 4 已從 dotfiles 移除）。
- **不**處理 Category A 剩餘工具（nvm-windows、gpg）與 Category D 多版本 toolchain。
- **不**碰 User PATH（Wave 1 已搞定 `~/.local/bin` 排序）。

## Decisions

### D1: Archive 模式 — `type = "archive"` × 1，**不**用 `archive-file` × N

**選**：1 條 `[".local/share/vim"]` entry，`type = "archive"` + `stripComponents = 1`（剝掉 zip 內的 `vim/` 頂層目錄，保留 `vim92/`）。結果：`~/.local/share/vim/vim92/{...}` 完整鏡像 vim distribution 內部結構。

**捨**：
- `type = "archive-file"` × N entries 抽單檔——vim.exe 需 4 個 DLL 在同目錄、runtime/ 需 2000+ 檔。技術上要 archive-file × ~2700，不可行。
- `type = "archive"` extract 到 `~/.local/bin/vim/`——bin 目錄被 install/uninstall.exe 污染（雖然 chezmoi-external 不會把它們 expose 到 shell 層，但語義上不乾淨）。
- 用 `~/.local/opt/vim/`（其他 Unix 慣例）——與 XDG `~/.local/share/` 慣例不一致。

**理由**：
- **`~/.local/share/` 是 XDG 標準應用資料目錄**：本身設計給「應用程式相關的非可執行檔（runtime data、模板、自帶資源）」。vim 的 runtime/ 結構正是這類資料；放這裡比 `~/.local/opt/` 或 `~/.local/lib/` 都更語義正確。
- **`stripComponents = 1` 保留 `vim92/`**：vim 的 runtime 預設 lookup 邏輯期待 `<dir>/vim92/runtime` 或 `<dir>/vim92/{autoload,syntax,...}` 結構；保留版本子目錄讓未來多版本並存成為可能（雖本 wave 不支援）。
- **Chezmoi `archive` mode 已成熟**：chezmoi documentation 明示 archive 支援 .zip / .tar.gz / .tar.bz2，stripComponents 行為與 tar `--strip-components=N` 一致，無實作風險。
- **空間成本可接受**：~56 MB 解壓。比 ffmpeg static binary（單 binary 100MB+）小一截；不需要單獨討論 storage budget。

### D2: 15 個 `.cmd` wrapper，**不**用 PATH addition 或 symlinks

**選**：在 `dot_local/bin/` 放 15 個純 ASCII `.cmd` wrapper 檔，逐一對應 scoop `vim.json` 的 `bin[]` 陣列。

Flag 對應表（完全鏡像 scoop manifest）：

| Wrapper | Underlying | Extra flag |
|---------|------------|------------|
| vim.cmd | vim.exe | (none) |
| vi.cmd | vim.exe | (none) |
| ex.cmd | vim.exe | -e |
| view.cmd | vim.exe | -R |
| rvim.cmd | vim.exe | -Z |
| rview.cmd | vim.exe | -RZ |
| vimdiff.cmd | vim.exe | -d |
| gvim.cmd | gvim.exe | (none) |
| gview.cmd | gvim.exe | -R |
| evim.cmd | gvim.exe | -y |
| eview.cmd | gvim.exe | -Ry |
| rgvim.cmd | gvim.exe | -Z |
| rgview.cmd | gvim.exe | -RZ |
| gvimdiff.cmd | gvim.exe | -d |
| xxd.cmd | xxd.exe | (none) |

Wrapper 範本（無 flag 的版本）：
```cmd
@echo off
"%USERPROFILE%\.local\share\vim\vim92\vim.exe" %*
```

有 flag 的版本：
```cmd
@echo off
"%USERPROFILE%\.local\share\vim\vim92\vim.exe" -d %*
```

**捨**：
- **新增 `~/.local/share/vim/vim92` 到 User PATH**：要透過 `run_onchange_` 腳本 `setx PATH` 與 .bashrc/.shell_common PATH 組裝雙改；多一個 PATH entry 跨 shell 同步、會把 install.exe / uninstall.exe / vimrun.exe 也 expose 到 PATH（隱憂：使用者 tab-complete `un` 可能跳出 uninstall.exe）；版本 bump 時 PATH 字串也要動。**否決**。
- **chezmoi `create_symlink_` 在 `~/.local/bin/` 建 symlinks 指向 share/vim/vim92/**：Windows 建 symlink 需 admin 或 Developer Mode（不是人人都開）；且 Windows symlink 對 `.exe` 的行為跨 shell 不一致（PowerShell vs cmd.exe vs Git Bash）；symlink 無法表達 flag（vimdiff = vim -d 需要的「同 binary 不同 flag」需求）。**否決**。
- **單一 wrapper + alias 偵測 `%~n0`**：寫一個 `vim-shim.cmd` 用 `%~n0` 取得呼叫名稱，再 dispatch 到正確 flag。理論上可行但 .cmd 寫起來囉嗦、可讀性差；每個檔都要是 alias 或 copy。**否決**——15 個小檔（每個 3 行）總共 ~600 bytes 反而比 dispatch 邏輯清晰。

**理由**：
- **與 Wave 1-6 一致**：所有既有 entries 都產生 `~/.local/bin/<exe>`，PATH 設定完全不變。Wave 7 的 wrapper 落在同一目錄，使用者體感無變化（`where.exe vim` 一樣回 `~/.local/bin/vim.cmd`）。
- **`.cmd` 跨 shell 可執行**：PowerShell / cmd.exe / Git Bash 都能直接執行 `.cmd` 檔（PowerShell 5.1+ 自動呼叫 cmd.exe 處理；Git Bash 走 `cmd //c`）。比 `.bat`、`.exe` shim 都簡單。
- **Wrapper 不走 chezmoi template**：`vim92` 字串是 vim minor version 函數（9.2.x → vim92、9.3.x → vim93）。Patch 版本升級（最常見場景，2-4 週 cadence）不需動 wrapper；minor 升級（每 1-2 年）才要 find-and-replace 15 個檔的 `vim92`。Template 化反而增加每次 review 的雜訊（每 patch bump 都要看 .tmpl 渲染結果），維護成本不划算。
- **逐檔可加減**：若使用者日後決定不要 `evim`/`eview`，刪 wrapper 即可，archive entry 不動。

### D3: Tag pinning — `v<version>` 單一變數

**選**：pin 一個 chezmoi template 變數
```toml
{{- $vimVersion := "9.2.0530" }}
```
URL 形式：`https://github.com/vim/vim-win32-installer/releases/download/v{{ $vimVersion }}/gvim_{{ $vimVersion }}_x64.zip`

**捨**：
- 用 `latest` rolling tag——vim release cadence 高（每日 patch），無 reproducibility，違反 Wave 1-6 一貫 explicit pinning。
- 用兩變數（`$vimTag` + `$vimAsset`）——vim asset 命名規律（`gvim_<version>_x64.zip`），不像 BtbN 有 git-describe 後綴；一個變數足以表達。

**理由**：
- **vim 上游命名一致**：tag = `v<MAJOR>.<MINOR>.<PATCH>`、asset = `gvim_<MAJOR>.<MINOR>.<PATCH>_x64.zip`。一個 `$vimVersion` 變數同時表達 tag 與 asset，無需第二變數。比 Wave 6 ffmpeg 的雙變數模式簡單。
- **Bump 流程清晰**：`gh release view <latest> --repo vim/vim-win32-installer` 查最新版本字串，更新 `$vimVersion` 即可。
- **Patch bump 不需動 wrapper**：vim 9.2.0530 → 9.2.0540 的 runtime dir 仍是 vim92，wrapper 字串不變。**僅** minor bump（9.2 → 9.3）需要同時改 `$vimVersion` + 15 個 wrapper 中的 `vim92` → `vim93`。

### D4: Unsigned zip，**不**用 signed 變體

**選**：`gvim_<version>_x64.zip`（unsigned）。

**捨**：
- `gvim_<version>_x64_signed.zip`（self-signed by vim-win32-installer maintainer）——self-signed cert 未必被企業 CA chain 信任；無 RTV (revocation) 機制；個人開發機無 EDR/AppLocker 通行要求。

**理由**：
- **與 scoop 預設一致**：scoop `vim.json` 用 unsigned（從 commit 早期至今）。本 wave 維持相同預設，最小化 break 風險。
- **大小相同**：實測 unsigned 與 signed 差距僅幾 KB（簽章本身大小）；無 storage 優劣。
- **未來可調整**：若使用者日後遇 SmartScreen 阻擋頻繁，可單純改 `gvim_..._x64.zip` → `gvim_..._x64_signed.zip` 一字串。

### D5: 為何 15 wrapper 全部鏡像（不只 vim+gvim+xxd）

**選**：保留全部 15 個 alias wrapper。

**捨**：
- 只裝 vim+gvim+xxd 三個 .cmd：節省 12 個檔，但 `vi`、`vimdiff` 在 Git Bash / make scripts / git mergetool 常用；若遷移後某天 `vimdiff` not found 反而是更大 surprise。
- 只裝 vim+gvim+xxd+vimdiff 四個：與全 15 個的 surface area 差距不大（每 wrapper ~40 bytes），不值得在 D 區辯論。

**理由**：
- **零 break 原則**：使用者今天打 `evim foo.txt` 能跑，遷移後也要能跑。完全鏡像 scoop bin 介面是最保險的選擇。
- **維護成本可接受**：15 wrappers × 3 行 ≈ 600 bytes 總 source。每個 wrapper 都是 boilerplate，review 時掃過去確認 flag 對應即可。
- **新檔不需單獨 spec**：scoop `vim.json` 的 bin[] 已是業界共識的「vim alias 標準集」（mirrors Vim 原生 distribution 在 Unix 的 symlink 集），不存在「應該裝哪些」的設計選擇空間。

### D6: 不修補 scoopfile.json drift

**選**：因 `vim` 從一開始就不在 `scoop/scoopfile.json` 內，無 entry 需要刪除。Proposal 明示此事實，避免 reviewer 誤以為遺漏。

**捨**：（不適用）

**理由**：與 Wave 5 D6、Wave 6 D4 一致——scoop drift 是歷史問題，每個 wave 都不主動修補。

## Risks / Trade-offs

- **R1: vim minor version bump 需手動同步 15 wrappers 中的 `vim92` 路徑**：vim 9.3 上來時，`$vimVersion := "9.3.0001"` 與 15 個 wrapper 中的 `vim92` → `vim93` 需在同一 PR 完成。漏改任一就 break。→ Mitigation: (a) Wave 7 memory entry 明示此 invariant；(b) `code:review-quick` 流程必看 wrapper 中 `vim92` 字串總數是否等於 15。長期可選 template 化，但 D2 已論證 template 化的維護成本更高。
- **R2: vim release GC 舊版本導致 URL 404**：GitHub release 通常不 GC，但理論上 maintainer 可手動刪除。→ Mitigation: 一般 GitHub Release 不會主動 GC（與 BtbN dated autobuild 不同）。萬一發生，bump `$vimVersion` 即可恢復。長期可考慮 `project_dotfiles_release_mirror` 啟動後改抓自家 mirror。
- **R3: gvim 右鍵選單於 scoop uninstall 後消失**：scoop `vim.json` post-install 跑 `install-context.reg` 註冊；scoop uninstall 不會反向解除（HKCU 殘留），但 menu 點擊會找不到原 scoop 路徑 `gVim.exe`。→ Mitigation: design.md / proposal.md 明示此 out-of-scope；使用者若依賴 menu 可手動跑 `~/.local/share/vim/vim92/install-context.reg`（檔仍存在）。Migration script 不主動處理 registry。
- **R4: `.cmd` wrapper 在某些 PowerShell job runner 下表現異常**：極端情況如 PS Remoting / Constrained Language Mode 下 `.cmd` invoke 可能受限；但日常使用 (`vim foo`、`vimdiff a b` 等互動) 不受影響。→ Mitigation: 驗證階段於 PowerShell 7 + cmd.exe + Git Bash 三種 shell 各跑一次 `vim --version`。
- **R5: `~/.local/share/vim/vim92/install.exe` 出現於 share 目錄**：純 archive extraction 副作用，不影響 PATH（`~/.local/share/vim/vim92` 不在 PATH 上），但語義上看起來怪。→ Mitigation: 不主動刪（chezmoi-external 不支援「下載後清理特定檔」；若強行用 run_onchange_ 腳本刪會與 chezmoi cache 競爭）。文件記錄此 cosmetic issue。
- **R6: chezmoi `archive` mode 在 Windows 上抽取大 zip 的效能**：~56 MB / 2669 檔。chezmoi 用 Go 原生 zip 庫，理論上跨平台一致。→ Mitigation: 首次 `chezmoi apply -v` 觀察解壓時間；若 >30s 記錄；後續 apply 走 cache hit 應 <1s。

## Migration Plan

1. PR merge 並推到 main 後，使用者下次 `chezmoi apply` 自動執行：
   - external entry：下載 `gvim_9.2.0530_x64.zip` 並解壓至 `~/.local/share/vim/`（產生 `vim92/` 子目錄）。
   - 15 個 wrapper `.cmd` 寫入 `~/.local/bin/`。
   - `run_once_after_migrate-scoop-wave7.ps1.tmpl`：卸載 scoop `vim`。
2. 驗證：
   - `where.exe vim` → 應回 `C:\Users\<user>\.local\bin\vim.cmd`（單一條目）。
   - `vim --version` → 應為 vim 9.2.0530，無 DLL not found 錯誤（驗證 archive 整包正確）。
   - `gvim --version` / `xxd -v` → 同上版本字串。
   - `vimdiff` / `evim` 等 alias → 應能啟動對應模式（vimdiff 進 diff 視窗、evim 進 easy mode）。
   - `scoop list vim` → 回 not installed。
   - `Test-Path "$HOME\.local\share\vim\vim92\vim.exe"` → True。
3. 回滾：`git revert` PR + `scoop install vim`。

## Open Questions

無。所有範圍決策已於 propose 階段與 user 確認。
