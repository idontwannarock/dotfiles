## Why

Dotfiles 目前透過 `WORKLOGS_PATH` 環境變數把 `createnewlog` / `gitpushlog` alias 指向 worklogs 本地 repo 內的 script。這個設計有三個問題：

1. **Alias 只是 script 捷徑、不切換 CWD**，所以從任意目錄呼叫 `createnewlog` 時，底下的 `gh workflow run` 和 `git fetch/checkout/pull` 都會因為「not a git repository」而爆（今天在 `~` 執行就踩到）。
2. **架構不一致**：memory 裡的 `Worklog 無本機 Repo` 決策已經把所有 worklog skills 改成「不讀本地檔案、只用 GitHub API + CLAUDE.md 的 github-repo」。但 scripts 這半邊沒跟上，dotfiles 仍然在配置 `WORKLOGS_PATH` 並產生 `~/.claude/worklog-config.md`。
3. **死碼堆積**：`scripts/set-worklog-config.ps1` / `.sh` 產生的 `worklog-config.md` 沒有任何 skill 會讀（`worklog-team-status/SKILL.md:104` 甚至明確註解「此 skill 不讀取任何本地檔案，無 worklog-config.md」），屬於架構決策遷移時沒掃到的殘渣。

## What Changes

- **新增**：`createnewlog` 在 PowerShell 與 bash/zsh 下都改為**函式**（不是 alias），直接觸發 GitHub workflow 並 watch run 完成：`gh -R idontwannarock/worklogs workflow run create-daily.yml` → 取得 run ID → `gh run watch <id> --exit-status`。完全不碰本地 git、不需要 CWD、不需要 `WORKLOGS_PATH`。
- **BREAKING 移除 `gitpushlog`**：從 `10-aliases.ps1` 與 `shell-common/base` 移除 dotfiles 這一側的 `gitpushlog` alias。使用者若仍需要本地 commit/push 備援，改為 `cd` 進 worklogs repo 使用該 repo 內的 `git-push.ps1` / `git-push.sh`。
- **BREAKING 移除 `createnewlog` 的本地分支 checkout**：新版只觸發並等待 workflow，不再自動 `git checkout worklog/{today}`。呼叫端若需要本地分支，自行 `cd` 進 worklogs repo 手動切。
- **BREAKING 移除 `WORKLOGS_PATH` 設定流程**：刪除 `scripts/set-worklogs-path.ps1` / `.sh`。`createnewlog` 不再依賴任何環境變數。
- **清除死碼**：刪除 `scripts/set-worklog-config.ps1` / `.sh`（產生的 `worklog-config.md` 無人讀取）。
- **Hardcode repo 名稱**：`idontwannarock/worklogs` 直接寫死在函式內，與 skills 在 CLAUDE.md 中的 hardcode 方式一致。
- **文件同步**：`docs/user-scripts.md` 和 `docs/bash.md` 移除 `WORKLOGS_PATH` / `set-worklog-config` / `set-worklogs-path` 相關段落，改述新的無設定 `createnewlog` 行為。

## Capabilities

### New Capabilities
- `worklog-workflow-trigger`: PowerShell 與 bash/zsh 下的 `createnewlog` 函式行為規範，包含觸發 workflow、等待 run、錯誤處理、repo 名稱 hardcode 策略。

### Modified Capabilities
- `shell-template-split`: 現有 scenario「各平台 shell-common 輸出包含 base」使用「worklogs aliases」作為 base 被正確引入的可觀測標記。因為 alias 已被函式取代，標記字串需要更新為「createnewlog 函式」。這是 scenario 文字更新，不改動 requirement 語意。

## Impact

**受影響檔案**：
- `Documents/exact__shared-profile.d/10-aliases.ps1` — 移除 `Set-Alias createnewlog`、`Set-Alias gitpushlog` 與 `$env:WORKLOGS_PATH` 檢查區塊；新增 `function createnewlog` 定義
- `.chezmoitemplates/shell-common/base` — 移除 `WORKLOGS_PATH` 區塊；新增 `createnewlog()` POSIX 相容函式定義
- `scripts/set-worklog-config.ps1` — **刪除**
- `scripts/set-worklog-config.sh` — **刪除**
- `scripts/set-worklogs-path.ps1` — **刪除**
- `scripts/set-worklogs-path.sh` — **刪除**
- `docs/user-scripts.md` — 移除 set-worklog-config / set-worklogs-path 章節
- `docs/bash.md` — 移除 `WORKLOGS_PATH` 相關段落

**使用者影響（breaking for current machine）**：
- 既有 `~/.bashrc` / `~/.zshrc` / PowerShell profile 仍有舊 alias 定義，下次 `chezmoi apply` 才會更新
- 既有 `~/.claude/worklog-config.md` 會留在原地（無人讀取，不影響任何流程），若在意可手動刪除
- 使用者在 shell rc 或 PowerShell profile 手動 export 的 `WORKLOGS_PATH` 不再有任何效果，可自行清理

**不受影響**：
- Worklog skills（`worklog-record`、`worklog-daily`、`worklog-team-status`）— 已經完全走 GitHub API 路徑
- Worklogs repo 本身的 script（`D:\ws\github\worklogs\create-new-log.ps1` 等）— 由使用者在該 repo 單獨調整為純本地備案模式
- CI / GitHub Actions workflow `create-daily.yml` — 觸發介面不變
