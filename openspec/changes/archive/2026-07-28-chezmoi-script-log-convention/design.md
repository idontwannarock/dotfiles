## Context

`home/` 底下有 41 支 `run_*.tmpl` 腳本（約 2,950 行），跨兩種 interpreter（bash / PowerShell）。目前的 log 現況是「半套慣例」：

- 起始 banner 有三種寫法並存：`=== CLI Tools Setup ===`、`=== Wave 6: Scoop cleanup ===`、以及完全沒有（`install-prereqs`、`set-git-hookspath`、`set-docker-host` 等 8 支）。
- 結束 banner 更亂：`=== Migration complete. ===`（wave 1–5）vs `=== Wave 6 migration complete. ===`（wave 6 起），同一批腳本的起訖文字對不起來。原因是起訖字串各自手寫、沒有單一來源。
- 段落標題（`# ── Claude Code ──`、`# --- (2) PATH reorder ---`）只存在於**註解**，`chezmoi apply` 的輸出看不到，所以 apply 中斷時無法從輸出定位到段落。
- 早退路徑（`exit 0` / `return`）大多不印結束 banner，輸出看起來像被截斷。

同時有大量逐字複製：`migrate-scoop-wave{2,3,4,5,6,7,12a}` 這 7 支內容**完全相同**、只差 `$pkgs` 一行（wave 11 多一段 orphan-shim 清理）；npm 安裝守衛在 `.sh` 與 `.ps1` 各寫一份；apt/brew 守衛在 `install-cli-tools.sh` 內部就寫了兩份。

約束：
- `.chezmoitemplates/` 的 `{{ template }}` 是**渲染期內嵌**，不是 runtime import，所以 fragment 沒有部署順序問題 —— 這是既有 `scripts/load-nvm` 已驗證的機制。
- chezmoi 的 `scriptState` 以腳本**內容 SHA256** 為 key（`chezmoi state dump` 可見同一支 `install-01-runtimes.sh` 有多筆不同 hash 紀錄），所以任何內容改動都會讓 `run_once_` 重跑。
- 開發機是 Linux/WSL，PowerShell 腳本無法在此實跑。

## Goals / Non-Goals

**Goals:**
- 讓 `chezmoi apply` 的輸出可回答三個問題：現在跑到哪支腳本、這段在做什麼（**目的**，不是段落代號）、這支跑完了沒（含失敗）。
- 起訖 banner 的文字來自**單一來源**，結構上不可能對不起來。
- 早退與失敗路徑也保證印出結束 banner。
- 消除逐字複製：相同形狀的腳本合併，共用邏輯抽成 fragment。
- 把上述寫進 `chezmoi-author` skill，讓下一支新腳本自動遵循。

**Non-Goals:**
- 不改任何安裝／移除／PATH 改寫的**實際效果**。這是純粹的 log 與組織重構。
- 不新增或移除任何被管理的工具，不動 `.chezmoiexternal.toml`。
- 不統一 bash 與 PowerShell 的 log **實作**（不可能），只統一**語意與輸出格式**。
- 不為 `modify_*` 腳本加 banner —— 它們的 stdout 就是檔案內容，印 log 會污染輸出。skill 需明確排除這類。

## Decisions

### D1: 六個 log 動詞，兩個 interpreter 語意對齊

<!-- evergreen-candidate -->
定義最小動詞集，兩邊輸出格式逐字一致：

| 動詞（sh / ps1） | 輸出 | 用途 |
|---|---|---|
| `log_begin` / `Log-Begin` | `=== BEGIN <title> ===` | 腳本開頭，**只呼叫一次** |
| `log_section` / `Log-Section` | `--- <purpose>` | 段落**目的**，取代原本的註解分隔線 |
| `log_step` / `Log-Step` | `    <msg>` | 實際動作（安裝、寫入） |
| `log_skip` / `Log-Skip` | `    <msg> (skipped)` | 冪等守衛命中 |
| `log_warn` / `Log-Warn` | `    !! <msg>` | 非致命問題 |
| `log_end` / `Log-End` | `=== END <title> (ok\|FAILED rc=N) ===` | 結尾 |

關鍵：**`log_end` 不接參數**，標題由 `log_begin` 存進變數（sh: `_LOG_TITLE`，ps1: `$script:LogTitle`）。這在結構上消滅了目前「begin 說 Wave 6、end 說 Migration」的漂移 —— 不是靠紀律，是靠沒有第二個地方可以寫錯。

考慮過的替代方案：讓 `log_end` 接標題並在 skill checklist 要求人工核對。否決 —— 那正是現況失效的機制。

### D2: 結束 banner 由語言機制保證，不靠人記得呼叫

<!-- evergreen-candidate -->
- **bash**：`log_begin` 內安裝 `trap _log_exit EXIT`。任何離開路徑（正常結尾、`exit 0` 早退、`set -e` 中止、未捕捉錯誤）都會印出結束 banner，並帶上 exit code。
- **PowerShell**：腳本主體包在 `try { ... } finally { Log-End }`。`return`（chezmoi ps1 腳本既有的早退慣例）會觸發 `finally`。

兩者不對稱是刻意的：各自用該語言最不易寫錯的機制，而非硬湊出同一種寫法。skill 需寫明「ps1 用 `return` 早退，不要用 `exit`」，因為 `exit` 繞過 `finally` 的行為不值得依賴。

### D3: fragment 檔名帶 interpreter 副檔名

既有 `scripts/load-nvm`、`scripts/load-sdkman` 無副檔名（因為只有 bash 版）。新 fragment 有雙 interpreter 版本，故採 `scripts/log.sh` / `scripts/log.ps1`。不回頭改既有兩支的檔名 —— 那會動到 `install-01-runtimes` 等腳本卻沒有實質收益。

新增的 fragment：

| Fragment | 提供 |
|---|---|
| `scripts/log.sh` | 六個 log 動詞 + EXIT trap |
| `scripts/log.ps1` | 六個 log 動詞（`Log-End` 供 `finally` 呼叫） |
| `scripts/npm-install.sh` | `npm_install <cmd> <pkg>` 冪等守衛 |
| `scripts/npm-install.ps1` | `Install-NpmPackage -Command -Package` |
| `scripts/pkg-install.sh` | `pkg_install <cmd> <pkg>`，渲染期依 `.chezmoi.os` 決定展開 apt 或 brew |
| `scripts/brew-cask-install.sh` | `brew_install_cask <cask>`（macOS）；cask 是 GUI app，多半不上 PATH，故以 `brew list --cask` 而非 `command -v` 判定 |
| `scripts/scoop-uninstall.ps1` | `Remove-ScoopPackage -Name -Reason`，含 orphan shim 清理 |

> 實作期補入 `brew-cask-install.sh`：`install-containers.sh` 與 `install-fonts.sh` 各有一份逐字相同的 `brew_install_cask`，正好命中本 change 自己訂的「同 interpreter 重複 2 次即抽取」門檻。

`pkg-install.sh` 用**渲染期**分支（`{{ if eq .chezmoi.os "darwin" }}`）而非 runtime 分支：產出的腳本只含該平台實際會走的路徑，可讀性與現有寫法一致。

### D4: 「合併」與「抽取」的判準

<!-- evergreen-candidate -->
- **相同形狀、只差資料 → 合併成一支 + 資料表。** 判準：把差異抽成表之後，剩下的控制流是否逐字相同。
- **獨特邏輯、共用工具 → 保留各自腳本，抽 fragment。** 判準：合併後是否需要用旗標或分支重新把它們拆開。

套用結果：

| 原腳本 | 處置 | 理由 |
|---|---|---|
| wave 2, 3, 4, 5, 6, 7, 12a | **合併** | 控制流逐字相同，只差 `$pkgs` |
| wave 11 (jdtls) | **合併** | 僅多 orphan-shim 清理，該行為提升為全體共用 |
| wave 1 (to-external) | 保留 + 用 fragment | 含一次性 User PATH 重排，與清理無關 |
| wave 8 (gpg) / 9 (nvm) / 10 (toolchain) / 12b (7zip) | 保留 + 用 fragment | 各含獨特的 env / 註冊 / 解壓邏輯 |

合併後的 `run_once_after_migrate-scoop-cleanup.ps1.tmpl` 以「套件 → 移除理由」表驅動，**理由直接餵給 `Log-Section`** —— 原本埋在檔頭註解的「為什麼移除這個」變成 apply 時看得到的輸出。這正是本 change 的核心意圖。

### D5: orphan-shim 清理維持 wave 11 語意，以 per-package opt-in 表達

`Remove-ScoopPackage` 提供 `-PruneShims` switch，**只有 `jdtls` 開啟**。

原先考慮把 shim 清理收斂為「只在實際 uninstall 後才清」（理由：沒被 scoop 裝過就不該有 scoop 產生的 orphan shim）。**否決** —— 既有 `tool-dependencies` spec 的「Wave 11 一次性遷移腳本」明確要求「scoop jdtls 未安裝時**仍**清殘留 shim（冪等）」，那是為了處理 scoop 自身狀態已損毀、`scoop list` 查不到但 shim 還在的情況。合併不是重新設計行為的時機；把它降級會讓已通過驗收的需求失效。

同理，也不把 shim 清理套用到全部套件：其餘 wave 的 spec 沒有這條，擴大行為等於在重構裡夾帶未經驗收的變更。

## Risks / Trade-offs

- **所有 `run_once_` 腳本會重跑一次** → 每支腳本的每個安裝都有 `command -v` / `Get-Command` 守衛，重跑是 no-op，只產生 skip 輸出。已與使用者確認接受。

- **合併後的 cleanup 腳本是全新 hash，在已跑完所有 wave 的機器上會完整重跑一次 scoop 清理** → 對已移除的套件是 no-op。但若使用者在 wave 跑完後**刻意**用 scoop 重裝了表內某個套件（例如 `docker`），重跑會再次移除它。這是原腳本本來就有的 desired-state 語意（表內套件 = 明確不由 scoop 管），且 wave 4/5/12a 已把 `dark`、`vimtutor`、`lazydocker`、`lens` 這些 soft-unmanaged 項目排除在表外。合併不擴大這個集合。

- **PowerShell 腳本無法在開發機（WSL）實跑** → 只能做 `chezmoi execute-template` 渲染驗證 + PowerShell 語法解析（若機器上有 `pwsh`）。實機 apply 抽查必須在 Windows 機器上補做，列為未完成的驗證項，不當作已驗證。

- **`log.sh` 必須與 `set -euo pipefail` 相容** → fragment 內部不得依賴未設定變數；`_LOG_TITLE` 需給預設值；EXIT trap 內不可觸發二次錯誤。

- **PowerShell 5.1 相容性** → 只用 `function` + `$script:` 作用域 + `Write-Host`，不用 PS7-only 語法。

- **輸出變得比現在冗長** → 段落目的與 skip 行都會印出。這是刻意取捨：apply 失敗時能定位遠比輸出簡短重要。skip 行縮排到第二層，視覺上可快速略過。

## Migration Plan

1. 建立 6 個 `.chezmoitemplates/scripts/` fragment。
2. 改寫 bash 腳本（可在此機實跑驗證）。
3. 改寫 PowerShell 腳本（渲染驗證）。
4. 合併 8 支 wave 腳本為 1 支，刪除原始檔（`run_*` 不部署到 target，毋須 `.chezmoiremove`）。
5. 更新 `chezmoi-author` skill 兩節 + checklist，render 兩個 wrapper 驗證無 `<no value>`。
6. `chezmoi execute-template` 全量渲染 + `chezmoi apply --dry-run` 驗證。

Rollback：本 change 不改變行為，回滾即 `git revert`；已重跑的 `run_once_` 腳本因冪等而無殘留副作用。

## Open Questions

- Windows 實機 apply 抽查何時補做？（依專案「先在機器上測 → 才回寫 source」原則，這條在本 change 只能走到 render 驗證為止，需在 Windows 機器上補完才算真正落地。）
