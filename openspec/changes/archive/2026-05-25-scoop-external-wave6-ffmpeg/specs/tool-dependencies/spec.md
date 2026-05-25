## ADDED Requirements

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
