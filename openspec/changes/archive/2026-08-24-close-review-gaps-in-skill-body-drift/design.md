## Context

上一輪的 review 抓出九條，本輪全收。三支 review 之外還有一項自查發現：`--git-common-dir` 在
`home/` 下共 27 個出現處，形態比上一輪假設的多。實測分類：

| 類別 | 例 | 需要旗標？ |
|---|---|---|
| 輸出直接當路徑用 | `pickup.md:7`、`handoff.md:20`、`coordinate.md:1092` | **要**，且置前 |
| 輸出餵給 `cd "$(…)" && pwd -P` | `finish-branch.md:24`、`worktree.md:11`、`dev-workflow.md:31`，及三支真腳本 | **不要**——該慣用法自己正規化 |
| 散文提及旗標名 | `repo-identity.md:24,64`、`claude-state.md:81,83`、`worktree.md:39` | 不是呼叫點 |
| 刻意的反例 | `coordinate.md:1102`、`repo-identity.md:30` | 必須保留錯誤寫法 |

三支真腳本（`claude-memory-seed:39`、`localfiles:17`、`post-checkout:14`）都已查證安全：
全部走 `cd`＋`pwd -P`，且都沒有用 `-C`。**沒有第二個真 bug**。

## Goals / Non-Goals

**Goals:**

- 讓上一輪立下的規則在自己的分支上為真。
- 把上一輪失效的驗證換成機器可執行的守衛，且該守衛在它守的檔案變動時**會被觸發**。
- 補上新規則缺的可觀測判準——一條讀者無法判斷自己踩到沒有的規則等於沒有。

**Non-Goals:**

- 不重寫 Step 4 以外的 `review-cross-model` 段落。
- 不動三支真腳本（已查證安全）。
- 不處理跨 repo 那一半（已另開 handoff）。

## Decisions

**D1：測試斷言「兩種合法形式」，不是「一種」。**
最直覺的規則是「凡 `--git-common-dir` 必配 `--path-format=absolute`」。否決：它會對六個安全的
`cd`＋`pwd -P` 呼叫點誤報。一支第一天就誤報六次的守衛會被關掉，然後這裡就從「沒有守衛」
變成「有一個沒人看的紅燈」——比沒有更糟。

**D2：非呼叫點與反例靠行內標記豁免，不靠啟發式。**
另一個選項是讓測試猜哪些行是散文（例如「行內有中文就跳過」）。否決：猜測會隨文字改寫而改變
判定，而改寫正是這類漂移發生的時機。沿用 `skill-name-map-axis.test.sh` 已建立的紀律——
豁免要顯式且要說理由：行內 `<!-- flag-order: <理由> -->`。標記在 markdown 不可見，且表格列
也放得下（`coordinate.md:1102` 是表格列，行上一列是另一列表格，所以標記不能靠「上一行」）。

**D3：Step 4 的 degrade 理由由「一次分類讀取」決定，不由不可觀測的事實決定。**
上一輪寫的新列，其 WHEN 是「pane 正停在信任提示上」——那是世界的狀態，讀者手上沒有任何
機制看得到它，而唯一看得到的 `herdr agent read` 在同節下方被禁止。這個循環是上一輪**新造**的。
解法是承認 `agent read` 本來就允許的診斷用途，並把它釘在流程的一個確定位置：
重送一次仍無檔案 → 讀一次**只為分類** → 依所見選 degrade 理由。收割與診斷的界線因此不是
「能不能讀」，而是「讀來當結果 vs 讀來分類失敗」。

**D4：`docs/` 補回內容邊界。**
`project-context` spec 是四分法。上一輪把 `specs/` 改成 `openspec/specs/` 時就在這一行上，
卻沒發現它少一格。這是「動了那一行才看得見」的漂移，屬本輪射程。

**D5：workflow 的 `paths:` 與測試同一輪落地。**
分開做的話，中間那段時間裡守衛存在但不會被觸發——而這正是本輪要修的失效形狀本身。

## Risks / Trade-offs

- **新測試把一條散文規則變成硬性契約** → 接受。它擋的是**形狀**：呼叫點的旗標位置。它擋不到
  的是語意——一個帶了正確旗標卻用在錯誤位置的算式仍然全綠。測試的註解 SHALL 明寫這一點，
  理由與 `skill-name-map-axis.test.sh` 相同：沒有標明母體的綠燈，下一個人會讀成「這一族已處理」。
- **豁免標記會被濫用當成消音鈕** → 部分接受。標記要求寫理由，而理由會進 diff 被 review 看到。
  這是紀律不是機制，與既有的 `axis: reader` 同一層級。
- **`grill.md`／`arch-review.md` 加錨點讓兩支不談 openspec 的 skill 出現 openspec 詞彙** → 接受。
  `arch-review` 那七處只需「repo root 的」修飾，不需要提 `openspec/`。

## Migration Plan

無。新測試在 CI 加一個 job step（既有迴圈自動撿 `tests/*.test.sh`），回退即 revert。

## Open Questions

無。
