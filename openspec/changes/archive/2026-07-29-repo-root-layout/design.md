## Context

Repo root 現況混雜四類項目，只有前兩類站得住腳：

| 類別 | 項目 | 位置是否有選擇 |
|---|---|---|
| 工具強制位置 | `.chezmoiroot`、`home/`、`.github/`、`openspec/`、`AGENTS.md`、`.claude/`、`.codex/`、`.agent/` | 無。Codex 只從 cwd 往上找 `AGENTS.md`，不讀 `.codex/AGENTS.md`；chezmoi 只認 root 的 `.chezmoiroot` |
| 不部署的基礎建設 | `docs/`、`tests/`、`README.md` | 有，但 root 是慣例位置 |
| 待編譯原始碼 | `claude/statusline/`、`passgen/` | 有，且目前命名有語意衝突 |
| 殘留物 | `scripts/`、`neovim/` | 有，且已造成故障 |

`scripts/` 的故障是這次的觸發點：它位於 chezmoi source root（`home/`）之外，chezmoi 完全看不到，但 `home/Documents/exact__shared-profile.d/10-aliases.ps1:1` 的 `scoopupdate` alias 指向 `$HOME\.local\bin\scoop-interactive-update.ps1`。`home/dot_local/bin/` 下沒有這支檔案，也沒有任何 `run_*` 腳本或 `.chezmoiexternal.toml` 條目會把它放過去，因此該路徑永不存在。`openspec/specs/tool-dependencies/spec.md:625` 的 scenario 卻斷言它「已部署」——spec 與現實脫節。

同性質的對照組就在隔壁：`home/dot_local/bin/switch-pwsh-to-msi.ps1` 是同樣「使用者手動執行的 Windows 輔助腳本」，放在 chezmoi source 內，正常部署。同一種東西被放在兩個地方，其中一份沒生效。

## Goals / Non-Goals

**Goals:**

- `scoopupdate` alias 在 Windows 上實際可執行，且 `tool-dependencies` spec 的斷言成為事實而非誤述。
- root `tests/` 有 CI 執行，名實相符。
- root 目錄數量下降，且每個剩下的目錄都能用一句話說明「誰在讀它」。
- 路徑變動不觸及已部署的 dotfiles，也不改變 release artifact 的名稱與下載 URL。

**Non-Goals:**

- 不動任何工具強制位置的項目（`AGENTS.md` 留在 root，`.claude/CLAUDE.md` 留在 `.claude/`；兩者的不對稱源自上游工具設計，不是本 repo 可解的問題）。
- 不重寫 statusline 或 passgen 的任何原始碼，只搬目錄。
- 不擴充 Pester 測試覆蓋範圍，只讓既有的那一支跑起來。
- 不改 `.chezmoiexternal.toml` 的下載邏輯。

## Decisions

### D1：scoop 腳本搬進 `home/dot_local/bin/`，而非讓 alias 指向 repo

**選擇**：`git mv scripts/scoop-interactive-update.ps1 home/dot_local/bin/`，刪除空的 `scripts/`。

**理由**：alias 已經寫成 `$HOME\.local\bin\...`，且同目錄已有兩支同性質腳本作為既定慣例。讓實作對齊既有慣例，比修改 alias 去遷就一個錯放的檔案便宜。

**替代方案**：把 alias 改成指向 repo checkout 路徑。否決——repo 的 clone 位置因機器而異，alias 會變成機器相依；且這等於承認 chezmoi 管不到自己的輔助腳本，與整個 repo 的前提矛盾。

<!-- evergreen-candidate -->
**推論出的通則**：任何需要在使用者機器上執行的檔案，一律放 `home/` 之下由 chezmoi 部署；root 只放「不部署」的東西。root 出現一個看起來像要被執行的腳本目錄，本身就是設計錯誤的徵兆。

### D2：行尾由 CRLF 轉 LF 是可接受的副作用

`.gitattributes` 中 `home/dot_local/bin/* text eol=lf`（第 33 行附近）排在 `*.ps1 text eol=crlf` 之後，後者被覆蓋。腳本搬進去後行尾變 LF。

**選擇**：接受，不加例外規則。

**理由**：同目錄的 `corp-ssh-askpass.ps1`、`switch-pwsh-to-msi.ps1` 早已是 LF；`.ps1` 的配置 interpreter 是 pwsh 7，讀 LF 正常（`.gitattributes` 中 `*.ps1.tmpl` 的註解已載明此事）。加例外只會讓規則更難讀。

### D3：`tools/` 而非 `src/` 或維持現狀

**選擇**：`claude/statusline/` → `tools/statusline/`，`passgen/` → `tools/passgen/`。

**理由**：兩者本質完全相同——repo 內唯二的可編譯原始碼，由 CI 產出 binary，再經 `.chezmoiexternal.toml` 拉回部署。`tools/` 一詞同時說明「是什麼」（工具程式）與「不是什麼」（不是 dotfile）。

root `claude/` 這個名字是主要問題：repo 內已有 `.claude/`（repo-local agent 設定）與 `home/dot_claude/`（部署到 `~/.claude/`），第三個 `claude/` 裝的卻是 Go 原始碼，與前兩者毫無關係。讀者必須點進去才知道差別。

**替代方案**：
- `src/`——否決。這不是一個應用程式的原始碼樹，是兩個互不相干的獨立工具，`src/` 暗示了不存在的整體性。
- 維持現狀——否決。`claude/` 的命名衝突不會自己消失，且 root 多兩格。

### D4：Pester workflow 只在相關路徑變動時觸發

**選擇**：`push` 到 main 與 `pull_request`，`paths` 限定 `tests/**`、`home/dot_local/bin/**`、workflow 自身。runner 用 `windows-latest`。

**理由**：`tests/corp-ssh-askpass.Tests.ps1` 黑箱測試 `home/dot_local/bin/corp-ssh-askpass.ps1`，兩邊任一變動都該重跑；其餘 dotfile 變動與它無關，全 repo 觸發只會拖慢無關 PR。windows-latest 自帶 Pester 5 與 pwsh，無須額外安裝步驟。

**注意**：測試用 `Split-Path -Parent $PSScriptRoot` 推 repo root 再 join `home\dot_local\bin\`，因此 `tests/` **必須**留在 root 下一層。這反過來確認了 `tests/` 的位置是對的，只是缺 CI。

### D5：`neovim/` 直接刪除，不搬不封存

**選擇**：`git rm -r neovim/`，更新 `README.md` 的目錄樹與棄用表格。

**理由**：README 已標示「已棄用、不部署」。git history 完整保留，需要時 `git show <sha>:neovim/...` 即可取回。留著只是讓 root 多一格、讓讀者多一次困惑。

### D6：一支 PR、四個獨立 slice

四項彼此無依賴（scoop 修復、Pester CI、`tools/` 收攏、`neovim/` 刪除各自可獨立驗證），但同屬「repo root 結構整理」一個主題，且都只動 root 佈局。合成一個 change、tasks 切四個 vertical slice，一次 review。

## Risks / Trade-offs

| 風險 | 緩解 |
|---|---|
| `tools/` 改名後 `release-statusline.yml` 的 `paths` filter 沒同步改到，push 後 CI 靜默不觸發，release 停在舊版而無人察覺 | 改完後在同一支 PR 內以實際 push 驗證 workflow 有跑；`statusline-release` spec 的 scenario 一併更新為新路徑 |
| scoop 腳本搬遷後未在 Windows 實機驗證，`scoopupdate` 仍然壞掉、只是換一種壞法 | 依專案規則（先在當前電腦測試再同步），本項的驗收條件是 Windows 上 `chezmoi apply` 後 `Get-Command scoopupdate` 能解析到實體檔案並可執行 |
| Pester workflow 首次執行即失敗（既有測試本來就沒跑過，可能已因 helper 變動而 stale） | 這正是加 CI 的目的。若首跑即紅，先判定是測試 stale 還是 helper 有真 bug，再決定修哪一邊——不得為了讓 CI 綠而刪測試 |
| `git mv` 跨目錄後 GitHub 的 blame/history 追蹤斷裂 | 純檔案搬移、內容不變，git 的 rename detection 可自動接續；不在同一個 commit 內同時搬移與修改內容 |
| 文件散落多處提及舊路徑，改漏造成 spec/docs 與現實再度脫節（正是本次要修的病） | 以 `grep -rn "claude/statusline\|passgen/\|scripts/\|neovim/"` 全 repo 掃描作為每個 slice 的收尾檢查 |

## Migration Plan

無 runtime migration——所有變動皆在 chezmoi source root 之外，或為新增部署檔。使用者端只需一次 `chezmoi apply` 取得新的 `~/.local/bin/scoop-interactive-update.ps1`。

Rollback：`git revert` 即可，無殘留狀態。唯一需注意的是 revert 後使用者端已部署的 `~/.local/bin/scoop-interactive-update.ps1` 不會自動消失，但那是一支無害的獨立腳本。

## Open Questions

無。四項的實作路徑與驗收條件皆已確定。
