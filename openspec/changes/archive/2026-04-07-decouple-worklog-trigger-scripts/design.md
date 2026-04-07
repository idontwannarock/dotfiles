## Context

今天 `createnewlog` 在 `~` 執行時爆出 `fatal: not a git repository`，追進去發現兩層問題：**近因**是 alias 不切換 CWD 導致底下的 `gh`/`git` 失敗，**遠因**是 dotfiles 這半邊的 worklog scripts 架構沒跟上 memory 裡的 `Worklog 無本機 Repo` 決策（skills 已全部遷移到 GitHub API，但 scripts + env var + config 檔還停留在舊架構）。

現有結構：

```
WORKLOGS_PATH env var ─┬─ set-worklogs-path.ps1/.sh (helper to set it)
                       ├─ set-worklog-config.ps1/.sh (generates ~/.claude/worklog-config.md)
                       ├─ 10-aliases.ps1: Set-Alias createnewlog $env:WORKLOGS_PATH\create-new-log.ps1
                       └─ shell-common/base: alias createnewlog=$WORKLOGS_PATH/create-new-log.sh

worklog-config.md ─── 無任何 skill 讀取（worklog-team-status 明確說明不讀）
```

目標結構：

```
createnewlog (PS function, inline in 10-aliases.ps1) ──┐
                                                       ├─ gh -R idontwannarock/worklogs workflow run create-daily.yml
                                                       ├─ gh run list ... --jq '.[0].databaseId'
                                                       └─ gh run watch <id> --exit-status

createnewlog (POSIX function, inline in shell-common/base) ── 同上
```

使用者是單一開發者（Howard Wang），跨平台會用（Windows PS7、macOS zsh、WSL bash）。

## Goals / Non-Goals

**Goals:**
- `createnewlog` 從任意 CWD 可呼叫，不依賴 git repo 或 env var
- PS 與 POSIX shell 行為完全一致（可觀測等價）
- 單一 commit 完成 dotfiles 端 `Worklog 無本機 Repo` 決策的遷移
- 清除所有死碼（`set-worklog-config.*`）與 orphan helper（`set-worklogs-path.*`）
- 錯誤處理明確：任何一步 `gh` 失敗都報錯並退出非零

**Non-Goals:**
- 不改 worklogs repo 本身的 script（`D:\ws\github\worklogs\*.ps1`、`*.sh`）— 由使用者在該 repo 另行處理為本地備案模式
- 不引入任何新的設定檔或環境變數機制
- 不改 worklog skills（`worklog-record` / `worklog-daily` / `worklog-team-status`）
- 不處理使用者機器上既有的 `worklog-config.md` 檔案（留著不影響任何流程；是否刪除由使用者自行決定）
- 不改 CI workflow `create-daily.yml` 的觸發介面

## Decisions

### Decision 1: Function vs Alias vs 外部檔案

**選擇：inline 函式定義（PS 的 `function` / POSIX 的 shell function）**

Alternatives:
- **A. 繼續用 alias 但指向 dotfiles 內新的獨立 script**（`Documents/exact__shared-profile.d/create-new-log.ps1`）
- **B. Inline function 直接寫在 `10-aliases.ps1` 與 `shell-common/base`**  ← 選這個
- **C. PS 用 function、bash 用 shell script**（不對稱）

理由：
1. **可維護性**：函式邏輯只有 ~15 行（`gh workflow run` + `gh run list` + `gh run watch` + 錯誤處理），拆成獨立檔只是增加 I/O
2. **部署簡化**：不需新增 chezmoi 部署路徑；直接跟著現有的 `10-aliases.ps1` 與 `shell-common/base` 一起 apply
3. **跨平台對稱**：PS 與 POSIX 都 inline 最對稱，沒有「一邊 function 一邊 script」的認知負擔
4. 使用者在 Q4 明確選了 (b)

Trade-off：`10-aliases.ps1` 的檔名開始不精確（裡面會有函式不只是 alias），但這是命名 cost 不是結構 cost，可接受。

### Decision 2: Repo 名稱 hardcode vs 變數

**選擇：Hardcode `idontwannarock/worklogs` 在函式內**

Alternatives:
- **A. Hardcode**  ← 選這個
- **B. 讀 `$env:WORKLOG_REPO` 或類似變數**
- **C. 解析 `~/.claude/CLAUDE.md` 裡的 `Worklog repo:` 行**

理由：
1. **一致性**：skills 已經在 CLAUDE.md 裡 hardcode `idontwannarock/worklogs`，scripts 跟著 hardcode 才符合 DRY 的精神（同一份事實只寫在兩個地方：CLAUDE.md 與 shell function，fork 的人一併改）
2. **零額外設定**：這正是本次 refactor 想達到的目的 — 移除 `WORKLOGS_PATH` 後不想引入另一個同類機制
3. **變更成本低**：Fork 者需要編輯 2 個檔（PS 函式 + POSIX 函式）就完，比「跨平台讀 CLAUDE.md」簡單數量級

### Decision 3: `gitpushlog` 的去留

**選擇：dotfiles 完全移除 `gitpushlog`**

Alternatives:
- **A. 從 dotfiles 完全移除**  ← 選這個
- **B. 改成 `gh workflow run push-worklog.yml`**（如果有這個 workflow）
- **C. 留在 dotfiles 當 worklogs repo 本地 script 的 alias**

理由：
1. **架構一致性**：本次 refactor 的原則是「dotfiles 的 workflow trigger scripts 全部直接對 GitHub，不碰本地 repo」。`gitpushlog` 本質是本地 `git add/commit/push`，不符合這個原則
2. **使用者明確意向**：Q2 的 (a)+(c) 表示「dotfiles 完全移除，worklogs repo 保留當本地備案」
3. **備案明確**：使用者若要本地 push，`cd $env:WORKLOGS_PATH; .\git-push.ps1` 只多兩個指令，不是嚴重痛點

### Decision 4: 錯誤處理細節

**選擇：每個 `gh` 呼叫後立刻檢查 `$LASTEXITCODE`（PS）/ exit code（POSIX），失敗立即 return 非零**

PS 的 `$ErrorActionPreference = "Stop"` 對 native executable 無效（今天這 bug 的一部分原因就是這個 — 原 script 的 `gh workflow run` 失敗後沒 throw），所以不能依賴。改為手動檢查 `$LASTEXITCODE`。

PS 端的錯誤回報統一走 `[Console]::Error.WriteLine(...)` 而非 `Write-Error`，避免在 caller 設 `$ErrorActionPreference = 'Stop'` 時 `Write-Error` 變成 terminating error throw 出去（與 POSIX 版的 `printf >&2; return 1` 行為對齊）。同時在每個邏輯失敗 return 之前**顯式** `$global:LASTEXITCODE = 1`，否則「empty run ID」這類分支會繼承前一次成功 native command 的退出碼（0），使 caller 誤判為成功。

POSIX 用 `set -e` 會影響整個 shell session，不適合放在 function 裡，改為每個 `gh` 呼叫後 `if [ $? -ne 0 ]` 明確處理。POSIX 端 `local var=""; var="$(cmd)"` 必須拆兩行 — `local var="$(cmd)"` 會讓 `$?` 變成 `local` builtin 的退出碼（永遠 0），靜默吞掉 substitution 的失敗。code 中有 NOTE 註解標明這個 invariant。

```
★ Insight ─────────────────────────────────────
PowerShell 7.4+ 有個實驗功能 $PSNativeCommandUseErrorActionPreference = $true，
啟用後 native exe 非零 exit code 會觸發 $ErrorActionPreference = "Stop"。
本次不採用，因為 (1) 還是實驗功能，(2) 會影響整個 profile 的行為，
(3) 函式內手動檢查 $LASTEXITCODE 語意最明確。
─────────────────────────────────────────────────
```

### Decision 4b: Polling 撈到舊 run 的 race

固定 sleep + 單次 query 是 race-prone（撈不到剛建立的 run）。第一版改成「最多 10 秒每秒輪詢、有結果就 break」，但這只解了「沒任何 run」的 race，沒解「歷史 run 存在但新 run 還沒 index」的 race — 第一個 poll 會立刻撈到舊 run，把舊 run 的歷史結果（已 `completed`）誤報成新 run 的結果。

修法：在 trigger **之前**先 capture `$prevRunId`（最近一次 run 的 ID），輪詢時要求 `candidate -ne $prevRunId` 才接受。處理三種狀態：
- 沒任何歷史 run：`prevRunId` 為空，第一個非空 `candidate` 直接 break
- 有歷史 run 且新 run 已 index：`candidate` 不等於 `prevRunId`，break
- 有歷史 run 但新 run 還沒 index：`candidate` 仍等於 `prevRunId`，繼續輪詢

仍保留 10 秒上限作為 hard timeout，超時則視為失敗（GitHub 異常或 workflow_dispatch 沒真正建立 run）。

### Decision 5: 文件檔的處理深度

**選擇：只刪除與 `WORKLOGS_PATH` / `set-worklog-*` / `set-worklogs-path` 相關的段落，不重寫整份文件**

`docs/user-scripts.md` 記錄所有 `scripts/` 下的 helper，刪兩個條目。
`docs/bash.md` 的 worklogs aliases 段落改寫為「`createnewlog` 作為內建函式直接觸發 GitHub workflow」。

不主動在這次 PR 裡為 `createnewlog` 新寫完整使用說明，以保持 change 範圍聚焦；若後續需要詳細使用手冊再開一個新 change。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 使用者習慣舊的 `createnewlog` 自動 checkout 本地 branch，新版不做會感到不便 | 在 commit 訊息與 docs 更新中明確說明 breaking change；使用者仍可 `cd $env:WORKLOGS_PATH && git checkout worklog/<date>` 手動處理 |
| 既有機器部署後 `WORKLOGS_PATH` 環境變數仍殘留，使用者可能以為還在用 | 屬於使用者自己的 shell history / profile 自 customization，dotfiles 不介入；在 docs 改動時加一行「如有自行 export `WORKLOGS_PATH` 可移除」 |
| `idontwannarock/worklogs` 未來若改名，需要同時更新 PS 與 POSIX 兩個函式 | Hardcode 的 trade-off；兩處 grep `idontwannarock/worklogs` 就能找到，實際成本可控 |
| `gh` 未登入時錯誤訊息可能不夠友善 | 依賴 `gh` 本身的錯誤訊息（夠清楚：`error connecting to... not logged in`）；不額外包裝 |
| `worklog-team-status` SKILL.md:104 的註解「不讀取 worklog-config.md」變成過時註解（檔案本身不再由 dotfiles 產生） | 該註解仍然正確（skill 確實不讀），不改；若看起來不合理可在後續 cleanup 處理 |
| 同時併發多個 `createnewlog`（人類使用者實務上不會發生）會讓 `prev_run_id` 比較失效 — 兩個 invocation 的 polling 都可能看到對方的新 run 並把它當成自己的 | 接受此 trade-off。`createnewlog` 是互動式單人 helper，不為並發場景設計；若未來需要 CI 多 worker 觸發，再改為從 `gh workflow run` 的 STDOUT 取得 dispatch ID（目前 gh 不直接給，需要 `--ref`/`--field` 配合 unique marker） |

## Migration Plan

1. 使用者在目前機器 `chezmoi apply` 後，新的 `10-aliases.ps1` 與 `shell-common/base` 生效，`createnewlog` 函式可用
2. 舊的 `~/.claude/worklog-config.md` 保留在原地（無人讀取），使用者可自行 `rm` 或保留
3. 使用者 profile 若手動 export `WORKLOGS_PATH`，不再有任何效果，可自行清理
4. 其他機器下次 `chezmoi update && chezmoi apply` 時一起遷移
5. Rollback：`git revert` 本次 commit 即可還原舊行為（但舊 bug 會回來 — 從非 git repo 目錄仍然會壞）
