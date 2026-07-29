## 測試 seam 說明

本 change 不改變任何執行期行為(spec 與文件的文字修正),沒有能變紅的測試 seam,依 `discipline-skills` 的「無可測 seam」條款**明說跳過 tdd**。

正確性由 verify-done 把關,關鍵驗證是 **`chezmoi apply` 產出在 change 前後 byte-identical** —— 這是「不改行為」這個非目標的唯一硬證據(見 Task 2)。

---

## 1. spec 修正(垂直切片:矛盾消失且判準留下)

- [x] 1.1 以 delta 的 MODIFIED 內容更新 `openspec/specs/claude-config/spec.md`:移除 commands 走 `exact_` 的敘述與其兩個 Scenario,保留 agents 部分
- [x] 1.2 於保留的 requirement 加入「commands/skills 不得改為 exact_」Scenario 與其理由
- [x] 1.3 擴充 `.chezmoiremove` requirement 涵蓋 `~/.claude/skills/`,並加入「非 chezmoi 管理的檔案不受影響」Scenario
- [x] 1.4 更新該 spec 的 `## Purpose`(現行敘述仍寫「`~/.claude/` 以 `exact_` 目錄管理」)
- [x] 1.5 grep 驗證:spec 內不再有「commands 由 exact_ 管理」類敘述

## 2. 行為不變的硬證據(blocked by #1)

- [x] 2.1 記錄改動前的 `chezmoi apply` 產出狀態(`chezmoi managed` 清單 + `~/.claude/commands`、`~/.claude/skills` 實際檔案列表)
- [x] 2.2 改動後重跑,比對兩份清單 byte-identical —— 證明本 change 未觸動部署行為
- [x] 2.3 確認 `home/dot_claude/` 下無任何檔名前綴被更動(`git diff --stat` 不應含該路徑)

## 3. 文件同步(可與 #1 平行)

- [x] 3.1 修正 `README.md:325` 目錄樹註解(`exact_commands / exact_agents` → 反映實際:`commands/`、`skills/` 非 exact_,`exact_agents/` 是)
- [x] 3.2 修正 `docs/claude-code.md:13` 目錄樹註解,並補一行說明為何 commands 不走 `exact_`
- [x] 3.3 grep 驗證 `exact_commands` 字樣在 repo 中不再出現於描述現況的位置
