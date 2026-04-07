## 1. PowerShell side

- [x] 1.1 編輯 `Documents/exact__shared-profile.d/10-aliases.ps1`：移除 `WORKLOGS_PATH` 檢查區塊與 `Set-Alias createnewlog` / `Set-Alias gitpushlog`
- [x] 1.2 在同檔新增 `function createnewlog`：依序呼叫 `gh -R idontwannarock/worklogs workflow run create-daily.yml` → `gh -R ... run list --limit=1 --jq '.[0].databaseId'` → `gh -R ... run watch $runId --exit-status`；每個 `gh` 後檢查 `$LASTEXITCODE` 並以 `Write-Error` + `return` 處理失敗；找不到 run ID 時以明確訊息退出
- [x] 1.3 驗證：使用者於 PS7 + `~` 執行 `createnewlog` 通過（2026-04-07）。靜態檢查也已通過：`pwsh -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile(...)"` parse ok

## 2. Bash/Zsh side

- [x] 2.1 編輯 `.chezmoitemplates/shell-common/base`：移除 `WORKLOGS_PATH` 檢查區塊與兩個 alias 定義
- [x] 2.2 在同位置新增 POSIX 相容的 `createnewlog()` 函式：等價邏輯（`gh -R idontwannarock/worklogs workflow run ...` → `gh ... run list ...` → `gh ... run watch ...`），每步 `if [ $? -ne 0 ]` 檢查並 `return` 非零；空 run ID 以明確訊息 `return 1`
- [ ] 2.3 驗證（**deferred — bash runtime 待之後在 WSL/Git Bash 機會驗證**）：靜態檢查已通過 `bash -n .chezmoitemplates/shell-common/base` ok。函式邏輯與 PS 等價，PS runtime 已驗證

## 3. Cleanup dead code and orphaned helpers

- [x] 3.1 刪除 `scripts/set-worklog-config.ps1`
- [x] 3.2 刪除 `scripts/set-worklog-config.sh`
- [x] 3.3 刪除 `scripts/set-worklogs-path.ps1`
- [x] 3.4 刪除 `scripts/set-worklogs-path.sh`
- [x] 3.5 確認 `scripts/` 下是否還有其他檔案引用以上被刪檔名（`grep -r set-worklog scripts/`）

## 4. Documentation sync

- [x] 4.1 更新 `docs/user-scripts.md`：移除 `set-worklog-config.*` 與 `set-worklogs-path.*` 的說明條目；如有 `WORKLOGS_PATH` 相關敘述一併刪除
- [x] 4.2 更新 `docs/bash.md` 與 `docs/powershell.md`：把 worklogs aliases 段落改寫為「`createnewlog` 作為內建函式直接觸發 GitHub workflow，不需要任何設定或 env var」
- [x] 4.3 `grep -rn "WORKLOGS_PATH\|set-worklog-config\|set-worklogs-path" docs/ scripts/ Documents/ .chezmoitemplates/` 確認無殘留引用（剩下三個皆為 intentional negative reference，標明「不讀 WORKLOGS_PATH」）

## 5. Memory update (auto-memory)

- [x] 5.1 更新 `C:\Users\user\.claude\projects\D--ws-github-dotfiles\memory\MEMORY.md` 與相關條目：`scripts/` 結構描述去掉已刪檔；命名慣例範例改為 `scoop-interactive-update.ps1`；`project_worklog_no_local_repo.md` 追加 2026-04-07 scripts 側補完段落

## 6. Validation

- [x] 6.1 `openspec validate decouple-worklog-trigger-scripts --strict` — pass
- [x] 6.2 `chezmoi diff` 檢查部署差異符合預期：`.shell_common` 與 `Documents/_shared-profile.d/10-aliases.ps1` 兩個 target 顯示 alias 區塊被新 function 取代，`scripts/` 的刪除不影響部署（已確認 `scripts/` 在 `.chezmoiignore.tmpl` 內）
- [x] 6.3 跨平台驗證：PS7 end-to-end 通過（2026-04-07）；bash 端 deferred（見 2.3）
