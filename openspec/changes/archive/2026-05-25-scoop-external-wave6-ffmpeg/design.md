## Context

承 Wave 1~5 將 scoop-managed CLI 遷至 `.chezmoiexternal.toml` 的工程脈絡（避開 Win32-OpenSSH SSH session 下 scoop shim/`current` junction 失效、把 source-of-truth 集中於 dotfiles repo）。Wave 6 範圍由 user 決定，啟動 Category A archive-pattern 系列的第一個工具 ffmpeg。設計重點：

- **archive-pattern 第一案的 reference 責任**：本 wave 確立 archive-pattern 在本 repo 的「規範實作」——後續 vim / nvm / gpg 都會抄這套樣板（toml entry 結構、migration script 範本、文件位置、URL pinning 策略），所以設計選擇要盡量保守、與既有 Wave 1-5 模式相容。
- **BtbN 上游模式特殊**：`BtbN/FFmpeg-Builds` 同時提供 rolling `latest` tag 與 dated tag (`autobuild-<date>-<HHMM>`)，且兩者 asset 檔名差距大（dated tag 包 git-describe 後綴）。要 pin 版本必須同時 pin tag 與 asset filename。
- **無 corp-ssh-askpass / env var 依賴**：跟 Wave 5 docker 需 `DOCKER_HOST` 不同，ffmpeg 純粹是 CLI binary，無 env var 也無 daemon。範圍比 Wave 5 更乾淨。

## Goals / Non-Goals

**Goals:**
- `~/.local/bin/{ffmpeg,ffprobe,ffplay}.exe` 三隻 binary 由 `.chezmoiexternal.toml` 自 BtbN/FFmpeg-Builds GitHub Release 下載抽出，pinning 至明確 dated tag + asset filename（reproducible across machines & time）。
- 既有 scoop `ffmpeg` 被 `run_once_after_migrate-scoop-wave6.ps1.tmpl` 卸載。
- `run_once_install-cli-tools.ps1.tmpl` 不再 `Install-ScoopPackage "ffmpeg"`（避免 self-violate spec，Wave 5 lesson learned）。
- 變更後 `ffmpeg -version`、`ffprobe -version`、`ffplay -version` 等命令行為與遷移前一致。
- 為後續 vim / nvm / gpg 留下可複用的 archive-pattern reference 結構。

**Non-Goals:**
- **不**動 macOS / Linux 安裝（brew / apt 已提供良好版本管理，無遷移需求）。
- **不**追求自動跟最新 nightly 版本（reproducibility 優先於即時更新；版本升級需 explicit PR）。
- **不**支援 shared build（DLL 依賴增加部署複雜度，static GPL 已涵蓋日常 transcoding 需求）。
- **不**修補 `scoop/scoopfile.json` 缺漏 ffmpeg 紀錄的 drift（既存歷史問題，超出本 wave 範圍；與 Wave 5 D6 一致）。
- **不**處理 Category A 其他工具（vim / nvm / gpg）與 Category D 多版本 toolchain，留給後續 Wave。
- **不**碰 User PATH（Wave 1 已搞定 `~/.local/bin` 排序）。

## Decisions

### D1: Asset 選擇 — `n8.1` stable channel + static GPL

**選**：`ffmpeg-n8.1-<git-describe>-win64-gpl-8.1.zip`（n8.1 stable 分支、static linked、GPL build）

**捨**：
- `ffmpeg-master-latest-win64-gpl.zip`（master nightly）—— breaking change 風險，跨 apply 可能行為飄移。
- `ffmpeg-n8.1-...-win64-gpl-shared-8.1.zip`（shared build）—— DLL 依賴增加部署複雜度，static 已足夠。
- `n7.1` 較舊穩定分支 —— BtbN 同時維護 n7.1 與 n8.1，n8.1 是當前穩定線推薦。

**理由**：
- **Reproducibility**：stable 分支 ABI/CLI 介面相對穩定，dated tag pin 後相同 binary 在所有機器一致。
- **單檔簡化**：static binary 無 `avcodec-*.dll` 等附屬檔，archive 內 `bin/` 只有 3 隻 `.exe`，配合 `archive-file` 模式抽出乾淨。
- **GPL 已涵蓋常用 codec**（H.264/H.265/AAC/Opus/VP9/AV1 等），個人開發機場景充分；若使用者有特殊 codec 需求可後續再評估 lgpl 或自編譯。

### D2: Tag pinning 策略 — dated tag + 2 vars，**不**用 `latest` rolling

**選**：pin 兩個變數
```toml
{{- $ffmpegTag := "autobuild-2026-05-24-13-16" }}
{{- $ffmpegAsset := "ffmpeg-n8.1.1-8-gb21e00eda5-win64-gpl-8.1.zip" }}
```
URL 形式：`https://github.com/BtbN/FFmpeg-Builds/releases/download/{{ $ffmpegTag }}/{{ $ffmpegAsset }}`

**捨**：
- `latest` tag + `ffmpeg-n8.1-latest-win64-gpl-8.1.zip` + `refreshPeriod = "168h"` —— chezmoi 每週重新抓最新 binary，跨機器/跨時間不 reproducible，違反 Wave 1-5 一貫的「explicit version pinning」。
- `latest` tag 不加 `refreshPeriod` —— chezmoi 預設可能整 session 都不重抓，行為不可預測。

**理由**：
- **與 Wave 1-5 一致**：每個既有 entry 都有對應的 `$<tool>Version` 變數，bump version 是 explicit commit。Wave 6 維持此習慣。
- **BtbN 命名 quirk 不可逃**：dated tag 的 asset 檔名含 `git-describe` 後綴（`n8.1.1-8-gb21e00eda5`），跟 `latest` tag 的 `n8.1-latest` 形式完全不同。要 pin 必須同時 pin tag + asset filename，多一個變數但換得 reproducibility。
- **Bump 工作量可接受**：版本升級時人工跑一次 `gh release view` 查最新 dated tag 與對應 asset，更新兩個變數即可。每年 2-4 次節奏。
- **記憶體文件記錄**：將 BtbN 上游模式特異性寫進 `reference_chezmoi_external_cli_tools.md` Wave 6 區塊，避免未來作者再次踩坑。

### D3: Archive 模式 — `archive-file` × 3 entries，**不**用 `archive` × 1

**選**：3 條 `[".local/bin/<binary>.exe"]` entry，type 為 `archive-file`，共用同一 URL，分別以 `path = "<archive-root>/bin/<binary>.exe"` 抽出三隻 binary。

**捨**：
- `type = "archive"` + extract 全部到 `~/.local/share/ffmpeg/` + 加 PATH entry —— 需新增 PATH 設定（Wave 6 之前無此需求）、target dir 命名需新慣例、PATH ordering 與 Wave 1 既有設計交互測試。引入新概念過多。
- 各條 entry 用獨立 URL —— BtbN 上游就是同一個 zip，沒有獨立資產。

**理由**：
- **沿用 Wave 1-5 模式**：所有既有 entries 都產生 `~/.local/bin/<exe>`，PATH 設定完全不變。Wave 6 新增的 3 條 entry 也落在同一目錄。
- **Chezmoi cache 行為**：chezmoi external 以 URL 為 cache key，3 條 entry 共用同一 URL 時 zip 只下載一次（後續 entries 從 cache 抽出），無頻寬浪費。
- **逐檔可選**：若未來 `ffplay`（GUI 播放器）證實不需要，可單獨刪掉那條 entry，不影響另外兩隻。`archive` 模式則整批進出。
- **未來 vim / nvm 不被此決策綁死**：vim 需要 `runtime/` 整目錄、nvm 需要多檔案 + symlink，那時再啟用 `archive` 模式並設計 PATH/env_set 結構也來得及。Wave 6 不需要為了「將來可能用到」而提前複雜化。

### D4: 不修補 scoopfile.json drift

**選**：因 `ffmpeg` 從一開始就不在 `scoop/scoopfile.json` 內，無 entry 需要刪除。Proposal 明示此事實，避免 reviewer 誤以為遺漏。

**捨**：（不適用）

**理由**：與 Wave 5 D6 一致——scoop drift（local 安裝沒 sync 回 scoopfile.json）是歷史問題，每個 wave 都不主動修補。修補會把 wave 範圍從「遷一個工具」擴大成「重審 scoopfile.json 全部 entry」，違反 wave 小而精的 ship 節奏。

## Risks / Trade-offs

- **R1: BtbN GC 舊 dated tag 導致 URL 404**：BtbN 為節省儲存可能 GC 較舊的 autobuild release（觀察過去 release 通常保留 30+ 天）。一旦 GC，`chezmoi apply` 在尚未抓過 cache 的新機器會失敗。→ Mitigation: 提案時 pin 最新 dated tag（保留期最長），文件記錄此風險；若實際發生 GC，bump 變數即可恢復。長期可考慮 `project_dotfiles_release_mirror` 啟動後改抓自家 mirror。
- **R2: n8.1 → n8.2 stable 分支切換不自動**：當 BtbN 推出 n8.2 後不會自動套用，需人工 bump asset filename。→ Mitigation: 此為設計目標（reproducibility），非 bug。記憶體文件提醒「bump 時注意 asset filename 也需更新」。
- **R3: static binary 缺少特定 codec**：BtbN GPL static build 排除部分 codec（如 fdk-aac）。→ Mitigation: 對個人 transcoding/截圖需求充分，若日後實際遇到缺 codec，再評估 switch 至 shared 或自編 BtbN nonfree。
- **R4: 既有機器若手動安裝 ffmpeg 至非 PATH 位置**：Wave 1 PATH ordering 已把 `~/.local/bin` 排前，scoop 卸載後 `where.exe ffmpeg` 預期只剩 chezmoi-external 抽出的 binary。→ Mitigation: 驗證步驟含 `where.exe ffmpeg` 必須回單一條目。
- **R5: chezmoi external 同 URL 3 條 entry 的下載去重未經本 repo 實證**：理論上 chezmoi 以 URL 為 cache key 應 dedup，但若實際不 dedup，3× 同 zip 下載也只是 ~120MB × 3 一次性損耗（後續 cache hit）。→ Mitigation: 觀察首次 `chezmoi apply -v` 輸出；若實際有 3 次下載，後續 wave 再評估改用 `archive` 模式。

## Migration Plan

1. PR merge 並推到 main 後，使用者下次 `chezmoi apply` 自動執行：
   - step 4 update entries：下載 zip 並抽出 `ffmpeg.exe` + `ffprobe.exe` + `ffplay.exe` 至 `~/.local/bin/`。
   - `run_once_after_migrate-scoop-wave6.ps1.tmpl`：卸載 scoop `ffmpeg`。
2. 驗證：
   - `where.exe ffmpeg` → 應回 `C:\Users\<user>\.local\bin\ffmpeg.exe`（單一條目）。
   - `ffmpeg -version` → 應為 BtbN n8.1 stable + git-describe 後綴；無 DLL not found 錯誤（static build 驗證）。
   - `ffprobe -version` / `ffplay -version` → 同上版本字串。
   - `scoop list ffmpeg` → not installed。
3. 回滾：`git revert` PR + `scoop install ffmpeg`。

## Open Questions

無。所有範圍決策已於 propose 階段與 user 確認。
