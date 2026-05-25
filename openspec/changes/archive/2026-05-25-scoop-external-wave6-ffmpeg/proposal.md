## Why

承 Wave 1~5 的 scoop → chezmoi-external 系列，剩 Category A archive-pattern (ffmpeg/vim/nvm/gpg) 四個工具未遷。ffmpeg 是 Category A 第一個遷的——上游無 corp-ssh-askpass 依賴連結、結構單純（3 隻獨立 binary，無 runtime 目錄、無 env var），是 archive-pattern 的最佳 reference 實作目標。Wave 6 完成 ffmpeg 之後，後續 vim/nvm/gpg 都能照搬同套 chezmoi-external + migration 腳本模式，遞減第一個工具踩坑的設計負擔。

## What Changes

**chezmoi-external 新條目（Windows-only）**：
- `~/.local/bin/ffmpeg.exe`、`~/.local/bin/ffprobe.exe`、`~/.local/bin/ffplay.exe`：從 `BtbN/FFmpeg-Builds` GitHub Release 下載 `ffmpeg-n8.1.*-win64-gpl-8.1.zip`（n8.1 stable channel + static GPL build），以 `type = "archive-file"` × 3 entries 共用同一 URL，分別抽出三隻 binary。版本以 dated tag pin（reproducible，與 Wave 1-5 一致）。

**Install script 清理**：
- `run_once_install-cli-tools.ps1.tmpl:39` 移除 `Install-ScoopPackage "ffmpeg"`，留註解標記遷移。

**Active migration on existing machines**：
- 新增 `run_once_after_migrate-scoop-wave6.ps1.tmpl`：`scoop uninstall ffmpeg` 若已安裝（冪等；scoop 未安裝時整支 skip）。
- **不**動 User PATH（Wave 1 已搞定 `~/.local/bin` ordering）。

**Source-of-truth 補洞**：
- `scoop/scoopfile.json` 從一開始就無 `ffmpeg` 記錄（跟 Wave 5 docker 同情況的歷史 drift）。本提案**不**修補此 drift（會擴大範圍），僅留下記錄。

**不動**：
- macOS / Linux 安裝（`run_once_install-cli-tools.sh.tmpl` 仍用 `brew_install` / `apt_install`）。Wave 1-5 一貫只動 Windows scoop。
- 既有 Wave 1+2+3+4+5 entries、migration 腳本、PATH 設定。

**Breaking changes**：
- 既有 Windows 機器執行 `chezmoi apply` 後，scoop `ffmpeg` 會被卸載。`~/.local/bin/{ffmpeg,ffprobe,ffplay}.exe` 接手；因 Wave 1 已把 `~/.local/bin` 排在 `~/scoop/shims` 之前，PATH lookup 自動命中新位置。
- 因 BtbN 上游靜態 binary build 排除部分 codec（按 GPL 許可），版本切換可能伴隨支援 codec 微幅變動——預期不影響日常 transcoding，但若使用者有 niche codec 需求需單獨驗證。

## Capabilities

### New Capabilities
（無）

### Modified Capabilities
- `tool-dependencies`：新增 3 條 requirement——`ffmpeg` / `ffprobe` / `ffplay` 三隻 binary 由 chezmoi-external 安裝；Windows install script 不再經由 Scoop 安裝 ffmpeg；Wave 6 一次性遷移腳本。

## Impact

**Code changes**：
- `.chezmoiexternal.toml`：新增 Wave 6 區塊，含 3 條 `archive-file` external entry 與 pinned `$ffmpegTag` + `$ffmpegAsset` 變數。
- `run_once_install-cli-tools.ps1.tmpl`：移除 `Install-ScoopPackage "ffmpeg"` 一行，於 `# ── Media ──────` 區段留註解標明已遷至 chezmoi-external。
- `run_once_after_migrate-scoop-wave6.ps1.tmpl`（新檔）：Windows-only，冪等 scoop uninstall ffmpeg。

**Existing machine state changes**：
- Scoop 卸載 1 個套件（`ffmpeg`）。
- `~/.local/bin/{ffmpeg,ffprobe,ffplay}.exe` 出現；後續 `ffmpeg -version` 等命令解析到新位置。
- User PATH **不變**。

**Memory updates（在 archive step 處理）**：
- `reference_chezmoi_external_cli_tools.md`：新增 Wave 6 區塊，記錄 ffmpeg 3 條 entry 與 BtbN dated-tag pin 模式（含 git-describe asset 檔名差異）。
- `project_scoop_external_wave4_candidates.md`：Category A 表格將 ffmpeg 劃掉，標記 Wave 6 完成；同時記錄 archive-pattern 第一個遷的設計選擇（`archive-file` × N 而非 `archive` × 1）。
- 視需要更新 `MEMORY.md` 索引。

**Out of scope（後續 Wave 候選）**：
- **archive-pattern 剩餘**：vim（需處理 runtime/ 目錄）、nvm（NVM_HOME/NVM_SYMLINK env vars）、gpg（corp-ssh-askpass 核心依賴 + gnupg.org NSIS 非 GitHub 來源）。
- **多版本 toolchain**：Category D（python/jdk/go/rustup/mvn）。
- **macOS/Linux ffmpeg 統一管理**：brew/apt 已提供良好版本管理，無遷移需求。
