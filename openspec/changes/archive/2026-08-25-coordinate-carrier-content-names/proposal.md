## Why

PR #124 為 `coordinate` 立了三格線間訊息載體,同一輪也立下**「序號是位置不是身分」**的禁令
——然後用「第一格／第二格/第三格」在三個檔案裡建了約 40 處位置指涉,**而那張載體表連編號都沒印**。

規則剛立就被自己違反。而且這裡比收尾清單**更**不穩定:收尾清單的「第五項」至少對得到一個印出來的序號,
「第一格」對不到任何東西——讀者得自己數表格的列。

前一輪判它可延後(三格是時間軸上的封閉分類,不像清單會增長);cross-model 判它是本 range 引入的 live defect。
**2026-08-25 使用者裁決:採 cross-model 立場,改內容命名。**

## What Changes

- **三格改內容命名**:`訊息格` / `檔案格` / `檔案＋通知格`。載體表加一欄印出名字,讓名字有錨。
- **新增三支守衛測試**。本協定自己那條〈取得嚴謹度的方法是守衛,不是告誡〉正面壓在這裡:
  改名只是把 40 處位置指涉換掉,沒有任何東西阻止下一個人寫回去。
  - (a) 章節交叉引用解析:`〈X〉` 要對得到同檔某個標題
  - (b) 位置指涉:禁 `第N項` / `第N格`
  - (c) 兩份 body 的門檻與觸發字元集同步(刻意複寫,2026-08-25 已漏改過一次)
- **`117 檔案`的論證改為結構性**。現行論證用「某 repo 下 117 個檔案、五天」證明 `attachments/` 無淘汰機制
  ——五天的窗證偽不了 30 天 TTL,而且數字會腐爛、讀者在別的機器上無法重驗。
- **spec 的序號禁令範圍**從「收尾清單」擴到「載體」。
- **CI 觸發路徑**補 `openspec/specs/**`:三支測試的母體含 `spec.md`,而現行 `paths:` 只有 `home/.chezmoitemplates/skills/**`
  ——只改 `spec.md` 的 PR 不會跑到這三支測試,而那正是最需要被擋的一種 PR。

## Capabilities

### New Capabilities

(無)

### Modified Capabilities

- `discipline-skills`: 三格載體 SHALL 以內容命名並在表上印出名字;序號禁令範圍擴到載體;
  `attachments/` 無淘汰機制的論證 SHALL 為結構性,SHALL NOT 依賴會腐爛的計數。

## Impact

- `home/.chezmoitemplates/skills/coordinate.md` —— 約 24 行位置指涉 ＋ 載體表 ＋ `117 檔案`那段
- `home/.chezmoitemplates/skills/dev-workflow.md` —— `first/third kind` 2 行(線側複寫)
- `openspec/specs/discipline-skills/spec.md` —— 約 12 行
- `context/principles.md:77` —— 1 行
- `tests/` —— 新增三支 `*.test.sh`
- `.github/workflows/test-shell.yml` —— `paths:` 補一列

**明文不動**:
- `context/principles.md:51` 與 `openspec/changes/archive/2026-08-13-.../design.md:40` 的**文件四格**
  (`specs/` / `design.md` / `context/` / `docs/`)——同字不同族,誤改不會有任何測試轉紅
- `openspec/changes/archive/` 下 11 個檔——歸檔是歷史記錄,不改原句
