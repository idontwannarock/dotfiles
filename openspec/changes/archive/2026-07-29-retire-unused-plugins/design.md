## Context

`run_onchange_install-03-claude-config` 目前對 `superpowers` 的退役處理是一段獨立的 `if`：偵測已安裝就 uninstall，另外兩段 `if` 清兩個 cache 目錄。要再納入 10 個 plugin，照這個寫法會變成 11 段 uninstall `if` 加 11 段 cache `if`，在兩個 interpreter 各寫一遍。

本 repo 的腳本慣例（`chezmoi-script-conventions` spec、`project.md`）對此有明確規定：同一 interpreter 內重複兩次以上的邏輯要抽出；抽掉資料後控制流逐字相同的，要合併成資料表驅動。11 份逐字相同的區塊正是這條規則指向的情形。

## Goals / Non-Goals

**Goals:**

- 這 10 個 plugin 的移除隨 `chezmoi apply` 傳播到每一台機器，而不是只在編輯者這台生效。
- 新增下一個退役項目時只需在資料表加一列，不必複製控制流。
- `.ps1` 與 `.sh` 兩版的控制流一致，差異僅在語法。

**Non-Goals:**

- 不動仍在使用的 4 個腳本安裝 plugin，也不動手動安裝的 `code-review`。
- 不改 `run_update-claude-plugins` 的更新迴圈（它依 `enabledPlugins` 迭代，uninstall 後自然不再觸及）。
- 不移除 `superpowers-marketplace` 註冊——`episodic-memory` 與 `elements-of-style` 仍由它供應。
- 不處理 plugin 以外的退役（那是 `.chezmoiremove` 的職責）。

## Decisions

### D1：退役清單為「plugin id → 退役理由」的資料表

**選擇**：一張表，每列 `@marketplace` 完整 id 加一句人類可讀的理由；uninstall 與 cache 清理各跑一次迴圈。

**理由**：理由字串會印進 apply 輸出，符合腳本 logging 契約「段落印出目的而非代號」。使用者看到的是「移除 playwright（改用 chrome-devtools MCP，27 個 tool 的 budget 不划算）」而不是一串 id。

**替代方案**：只列 id、不帶理由。否決——退役決策的 why 若不寫在資料旁邊，半年後沒人記得為什麼移除，容易被「順手加回來」。

### D2：cache 路徑由 id 推導，而非另列一張表

**選擇**：`<id>@<marketplace>` 拆成 `~/.claude/plugins/cache/<marketplace>/<id>`。

**理由**：cache 目錄佈局就是這個結構（已由現行 superpowers 清理程式碼證實：`cache/claude-plugins-official/superpowers` 與 `cache/superpowers-marketplace/superpowers`）。推導比維護第二張表不容易漂移。

**保留的例外**：現行程式碼另外清 `cache/superpowers-marketplace/superpowers`——那是防禦性清理（superpowers 曾經來自該 marketplace），推導不出來。spec 明文要求保留，故在表外單獨保留這一筆。

### D3：uninstall 前先查 `claude plugin list`，不盲目呼叫

**選擇**：沿用現行作法，比對 `$installedPlugins` / `$INSTALLED_PLUGINS` 快照，未安裝就 `log_skip`。

**理由**：對未安裝的 plugin 呼叫 `claude plugin uninstall` 會噴 stderr。既有 spec 有一條 scenario 要求「plugin 指令輸出 stderr 時腳本仍完成」，但讓 11 個 no-op 每次 apply 都噴一次錯誤訊息，會把 apply 輸出洗成雜訊，違反 logging 契約。先查再做，輸出乾淨且語意正確。

**注意**：快照在迴圈前取一次即可——uninstall 不會讓其他 plugin 從清單消失。

### D4：cache 清理無條件執行，不綁 uninstall 結果

**選擇**：不論 plugin 當下是否安裝，都檢查並清除 cache 目錄。

**理由**：uninstall 會清 `installed_plugins.json` 與 `enabledPlugins`，但**留下 cache 目錄**（現行程式碼的註解已載明此事）。若把 cache 清理綁在「這次有 uninstall」的條件下，那些先前已手動 uninstall、只剩 cache 的機器就永遠清不掉。兩者各自冪等、各自獨立。

### D5：`code-review` plugin 不列入退役

**選擇**：保留，並在文件標明它是手動安裝、未納入腳本。

**理由**：它仍在使用（提供 `/code-review`）。它沒被腳本安裝是另一個缺口——換機時要手動補——但把它加進**安裝**清單是獨立的決定，不在本 change 範圍。

## Risks / Trade-offs

| 風險 | 緩解 |
|---|---|
| 誤刪仍在使用的東西：`code-simplifier`、`pr-review-toolkit` 與 repo 內同名的 agent 容易混淆 | 已查證：`code-simplifier`、`code-reviewer` agent 來自 `home/dot_claude/exact_agents/code-review/`，由 chezmoi 部署，與 plugin 無關。退役 plugin 不影響它們 |
| `context7` 曾被 global CLAUDE.md 指名要求查詢 library 文件 | 該指令要求的是「查 context7」這個行為；plugin 退役後若確實需要，應以 MCP server 形式重新提供。本 change 只移除未使用的 plugin，不改 CLAUDE.md 的指引 |
| 11 筆 uninstall 讓 apply 變慢 | 只有實際安裝過的才會呼叫 CLI，其餘是字串比對；乾淨機器上整段是 11 次 `log_skip` |
| 資料表在 `.ps1` 與 `.sh` 之間漂移 | 兩份表內容相同但語言不同，無法共用（`.chezmoitemplates/scripts/` 片段以 interpreter 分檔）。以 spec 條文列出完整清單作為單一事實來源，兩邊對照它 |

## Migration Plan

無 schema 或狀態遷移。使用者端下次 `chezmoi apply` 自動收斂：已安裝的被 uninstall，cache 被清除，未安裝的靜默跳過。

Rollback：`git revert` 後腳本不再 uninstall，但**已被移除的 plugin 不會自動裝回來**——需要的話手動 `claude plugin install`。這是退役類變更的固有性質，非本實作的缺陷。

## Open Questions

無。
