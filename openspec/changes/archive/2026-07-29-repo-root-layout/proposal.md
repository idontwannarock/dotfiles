## Why

Repo root 目前混雜三類東西：工具強制位置（`.chezmoiroot`、`.github/`、`openspec/`、`AGENTS.md`）、待編譯原始碼（`claude/statusline/`、`passgen/`）、以及沒有作用的殘留物（`scripts/`、`neovim/`、未被 CI 執行的 `tests/`）。第三類已經造成實際故障：`scripts/scoop-interactive-update.ps1` 位於 chezmoi source root（`home/`）之外，chezmoi 看不到它，但 `home/Documents/exact__shared-profile.d/10-aliases.ps1` 的 `scoopupdate` alias 卻指向 `$HOME\.local\bin\scoop-interactive-update.ps1`——那個路徑永遠不會存在，alias 是空砲，且 `tool-dependencies` spec 誤述它「已部署」。

## What Changes

- **修復 `scoopupdate`**：把 `scoop-interactive-update.ps1` 從 root `scripts/` 移入 `home/dot_local/bin/`，與同性質的 `switch-pwsh-to-msi.ps1` 併肩，使 alias 指向的路徑真的被 chezmoi 部署。移除空掉的 `scripts/` 目錄，`docs/user-scripts.md` 隨之更新。
- **Pester 測試進 CI**：新增 windows-latest workflow 執行 `tests/`，讓 root `tests/` 名實相符。`tests/corp-ssh-askpass.Tests.ps1` 目前無任何 CI 執行。
- **編譯來源收攏**：`claude/statusline/` → `tools/statusline/`，`passgen/` → `tools/passgen/`。root 的 `claude/` 這個名字與 `.claude/`（repo-local agent 設定）、`home/dot_claude/`（部署到 `~/.claude/`）語意衝突，實際內容卻是 Go 原始碼。
- **移除 `neovim/`**：README 已標示已棄用且不部署，git history 保留可還原。

無 **BREAKING**：三項路徑變動皆在 chezmoi source root 之外，不影響已部署的 dotfiles；release 產出的 tag 名稱與 artifact 名稱不變，`.chezmoiexternal.toml` 的下載 URL 因此不受影響。

## Capabilities

### New Capabilities
- `pester-test-ci`: PowerShell 腳本的 Pester 測試在 GitHub Actions windows runner 上自動執行的契約——觸發條件、runner、失敗即紅。

### Modified Capabilities
- `tool-dependencies`: `scoop-interactive-update.ps1` 的來源位置由 root `scripts/` 改為 chezmoi source root 內的 `home/dot_local/bin/`，使既有的「部署到 `~/.local/bin/`」條文從誤述變為事實。
- `statusline-release`: statusline 原始碼路徑由 `claude/statusline/` 改為 `tools/statusline/`，workflow 觸發的 path filter 條文隨之改變。
- `chezmoi-structure`: repo root 非部署項目清單改變（`scripts/`、`neovim/` 移除，`claude/`、`passgen/` 併為 `tools/`）。

## Impact

| 類別 | 影響 |
|---|---|
| chezmoi source | 新增 `home/dot_local/bin/scoop-interactive-update.ps1` |
| CI | `release-statusline.yml` 三處路徑；新增 Pester workflow |
| 文件 | `README.md` 目錄樹與棄用表格、`docs/user-scripts.md`、`docs/claude-code.md` |
| spec | `tool-dependencies`、`statusline-release`、`chezmoi-structure` 三支 delta |
| skill | `home/.chezmoitemplates/skills/chezmoi-author/windows.md` 提及 `scripts/scoop-interactive-update.ps1` 的路徑 |
| 刪除 | root `scripts/`、`neovim/`、`claude/`、`passgen/` |

`.gitattributes` 無須改規則，但 `scoop-interactive-update.ps1` 的行尾會因搬遷而由 CRLF 轉為 LF：`home/dot_local/bin/* text eol=lf` 排在 `*.ps1 text eol=crlf` 之後，後者被覆蓋。同目錄的 `corp-ssh-askpass.ps1`、`switch-pwsh-to-msi.ps1` 早已是 LF，且 `.ps1` 的 interpreter 是 pwsh 7，讀 LF 正常——與既有慣例一致，非退化。

不受影響：`.chezmoiexternal.toml`（下載 URL 綁 release tag 而非原始碼路徑）、`renovate.json`（custom manager 只掃 `.chezmoiexternal.toml`，且 statusline/passgen 本就排除追蹤）。
