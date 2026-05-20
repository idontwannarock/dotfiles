## Context

延伸 Wave 1 的 `.chezmoiexternal.toml` 模式至剩下 6 個 chezmoi-managed scoop 工具。Wave 1 的 design（`openspec/changes/archive/2026-05-18-scoop-external-wave1/design.md`）已建立全部框架。本 design 只記 Wave 2 特有的決策。

## Goals / Non-Goals

**Goals**：
- 6 個工具脫離 scoop，改由 `.chezmoiexternal.toml` 管理至 `~/.local/bin/`
- 跨機器版本一致（git 為 source of truth）
- 既有機器無 PATH 變動（Wave 1 已修好）

**Non-Goals**：
- 自家 release mirror（supply-chain pinning）→ 已記入 `project_dotfiles_release_mirror.md`，未來 wave
- 改變 fresh-VM bootstrap 機制（Wave 1.5 task 3 已修；hugo/kubectl 等不被 modify_ 引用，不需要重複 setup-paths）
- 觸及非 chezmoi-managed 的 scoop 工具（bun/gh/lazydocker/pwsh 都是使用者自裝）

## Decisions

### D1: kubectl 改用官方 `dl.k8s.io` 而非 GitHub Release

`kubernetes/kubernetes` GitHub Release 不提供 binary asset。官方 distribution channel 是 `dl.k8s.io/release/<version>/bin/<os>/<arch>/<binary>`——Kubernetes 官方靜態檔案 CDN，比 GitHub Releases 更穩定（與 k8s.io 整體生命週期一致）。

例：`https://dl.k8s.io/release/v1.36.1/bin/windows/amd64/kubectl.exe`。

**Alternative considered**：自家 build kubectl from source。Reject——版本追蹤工程過大，沒理由不用官方。

### D2: hugo 一律用 `extended` 版本

Scoop 同時有 `hugo` 與 `hugo-extended` 套件。chezmoi-external 統一只取 extended——extended 是 strict superset（多 SASS/SCSS 支援，binary 體積大 ~5 MB）。

→ `.chezmoiexternal.toml` 一個 `~/.local/bin/hugo.exe` entry，source 為 `hugo_extended_<ver>_windows-amd64.zip` 內的 `hugo.exe`。

**Alternative considered**：兩個 binary（hugo + hugo-extended）並存。Reject——磁碟與認知雙重浪費；extended 已可滿足全部 use case。

### D3: nexttrace 用 V1 release，不用 NTrace-core

上游有兩個 repo：
- `nxtrace/NTrace-V1`：穩定 release，最新 v1.6.5（2026-04-xx）
- `nxtrace/NTrace-core`：開發中 V2，較不穩

選 V1 因為 scoop 裝的也是 V1 版本，behaviour 對齊。將來 V2 stable 後可再 bump。

### D4: Wave 2 migration 腳本不做 PATH 重排序

Wave 1 的 `run_once_after_migrate-scoop-to-external.ps1.tmpl` 已把 `~/.local/bin` 排在 `~/scoop/shims` 之前。Wave 2 工具同樣在 `~/.local/bin`，不需要再排一次。

新檔 `run_once_after_migrate-scoop-wave2.ps1.tmpl` 只做 scoop uninstall，沿用 Wave 1 的 idempotent 模式（scoop 不存在或套件未裝就 skip）。

### D5: 不擴充 setup-paths 腳本

`run_onchange_before_setup-paths.ps1.tmpl`（fresh-VM bootstrap）只 bootstrap `jq.exe`，因為只有 jq 被 modify_ 引用。Wave 2 工具沒被任何 modify_ 引用，所以不需要在 step 3 提前下載——step 4 的 external 機制下載即可。

若將來有 modify_ 引用其他 ~/.local/bin 工具，再回頭擴充 setup-paths。

## Risks / Trade-offs

**[scoop 卸載 hugo / hugo-extended 影響使用者習慣]** → Mitigation：使用者目前實際上對 hugo extended 行為依賴度低；若有 site project 鎖死 vanilla hugo，仍可在 site repo 內裝其他版本。

**[CalVer 的 yt-dlp 版本號難判定 stable]** → yt-dlp 維護者每 1-3 個月發新 release，版本號就是日期。Mitigation：在 `.chezmoiexternal.toml` 註解標明 last bump date，避免落後太久；長期可用 GHA 自動 PR。

**[kubectl 官方 URL 一旦變更（雖然極不可能）]** → Mitigation：將來 mirror 計畫（`project_dotfiles_release_mirror.md`）會把 binary 收進自家 release。

**[archive 內含版本號的 path 變動]** → golangci-lint 內部路徑是 `golangci-lint-<ver>-windows-amd64/golangci-lint.exe`，版本 bump 時 `path` 也要跟著改。Mitigation：用 chezmoi template 把 `$ver` 變數同時 inject 到 url 與 path（一處 source of truth）。

## Migration Plan

1. Implement entries + script edits（一次性 PR）
2. 當前機器 `chezmoi apply` 確認：
   - 6 個工具下載到 `~/.local/bin/`
   - scoop 卸載 7 個 entries
   - 工具能呼叫且版本正確
3. Squash/normal merge
4. SSH session 驗證：透過 Tailscale 從另一台 SSH 進來，確認 `kubectl version`、`yt-dlp --version` 等可正常啟動（無 scoop shim 雷）
