## Why

上一輪（`2026-08-24-fix-skill-body-drift`）的 review 抓出九條，其中一條是上一輪**自己造成的**：
`session-handoff` spec 現在要求四支 skill 一致採用旗標置前寫法，而 `pickup.md:7` 整個**省略**了
`--path-format=absolute`——同一個分支既立下規則也違反它。上一輪的驗證是
`grep -- "--git-common-dir --path-format"`，它預設錯誤的形狀是「順序顛倒」，對「根本沒有那個旗標」
結構性失明，而該項任務仍被標成完成。

其餘各條同源：新加的規則沒有可觀測判準（`review-cross-model` Step 4 新列與「沒有 findings 檔」
外顯訊號相同卻導向不同 degrade 理由）、新表格與它上方兩行的舊敘述直接矛盾、以及範圍判斷
用錯尺度（`context/` 漂移的文脈是 session 不是檔案，所以 `grill.md` 才是最高風險位置，
而它沒被改）。

## What Changes

**正確性**

- `pickup.md`：錨點算式補上 `--path-format=absolute` 並置前，與 `handoff`／`handoff-list`／
  `arch-review` 一致。
- `review-cross-model.md` Step 4 開頭那句「Treat only `idle` and `done` as success」改寫——
  它與下方新表格直接矛盾，而由上而下讀的 agent 會停在它。
- `review-cross-model.md` Step 4 補上**分辨規則**：`idle`/`done` 且 findings 檔不存在時，
  先依 Step 3 重送一次；仍無檔案才以 `herdr agent read` **分類一次**（可見信任／授權提示 →
  `counterpart blocked on input`，否則 → `counterpart produced no findings file`）。
  這同時解掉「`agent read` 不得用於收割」與「你必須讀才知道是不是失敗」的循環。
- 表格補上 `idle`/`done` 但無 findings 檔那一列，指向上述流程——加了檔案條件後表格看起來窮舉，
  讀者不會再往下走到 Step 3。

**範圍修正**

- `grill.md`（2 處）、`arch-review.md`（7 處）的裸 `context/` 一併帶錨點。上一輪以「該檔提到
  openspec 幾次」判定風險，尺度錯了：漂移發生在 session 的文脈，而 grill 就跑在 OpenSpec 流程裡。
- `dev-workflow.md`：刪掉 L170 的贅餘錨點（同節標題九行內已錨定，且該行撐破檔案行寬）；
  L161 改寫成主詞不被破折號插斷；內容邊界由三分法補成正典的**四分法**（補回 `docs/`）。

**守衛**

- 新增 `tests/path-format-flag-order.test.sh`：掃 `home/` 下的 skill body 與 reference，
  對每個 `--git-common-dir` 的**呼叫點**斷言它是兩種合法形式之一——旗標置前，或
  `cd "$(…)" && pwd -P` 自行正規化。非呼叫點（散文提及旗標名）與刻意的反例需帶標記說明理由。
- `.github/workflows/test-shell.yml` 的 `paths:` 補上 `home/.chezmoitemplates/skills/**` 與
  `home/dot_agent/reference/**`——否則這支守衛不會在它要守的檔案變動時執行。

**文字**

- `repo-identity.md`：修掉「sit in a file this long」（原意 for this long）、刪去 `actually`，
  並讓該段承載 `coordinate.md` 已有的具體輸出（`.git` vs `../.git`）而非抽象重述。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `cross-model-review`: 「收斂判定區分 blocked」的新 scenario 補上可觀測判準與分辨順序；
  degrade 理由的選擇 SHALL 由一次分類讀取決定，而非由不可觀測的事實決定。
- `session-handoff`: 「repo slug 取自 git common dir 的父目錄」——把「SHALL 一致採用置前寫法」
  這條無偵測器的義務改為有 scenario 可驗，並承認第二種合法形式（`cd`＋`pwd -P`）。
- `tool-dependencies` 或 `pester-test-ci` 一類的 CI 能力：若既有 spec 已規範 `test-shell.yml`
  的觸發範圍則改之，否則不動 spec，僅改 workflow。

## Impact

- `home/.chezmoitemplates/skills/`：`pickup.md`、`review-cross-model.md`、`grill.md`、
  `arch-review.md`、`dev-workflow.md`
- `home/dot_agent/reference/repo-identity.md`
- `tests/path-format-flag-order.test.sh`（新增）、`.github/workflows/test-shell.yml`
- spec delta：`cross-model-review`、`session-handoff`
- 新測試會對六個既有的 `cd`＋`pwd -P` 呼叫點與十個散文提及做出判斷，全部必須綠——
  一支第一天就誤報的守衛會被關掉。
