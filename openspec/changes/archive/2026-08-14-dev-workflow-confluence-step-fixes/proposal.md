## Why

`dev-workflow-confluence-step`（commit `283b7cb`）的 review 找到兩個讓機制實際上跑不起來的缺口，以及四處自相矛盾的敘述。

最嚴重的是：共用 body 的 step 2b 從未被更新。它宣稱「step 2b 已經會讀 registry」，但 2b 的指令只列出 main repo path 與 active-workflows path，且新增列時不會產出第四欄。照字面執行的 agent 既讀不到 `Doc Target`，新列也會靜默退回三欄格式——`none` 狀態因此永遠無法生效。

其次，body 只解釋了 `none` 是什麼，從未說「跳過」。body 是模型 runtime 唯一會讀的東西，所以在標記 `none` 的 repo 上它仍會套判準、仍可能提案，正是這個 change 原本要防的雜訊。

## What Changes

- 共用 body 的 step 2b 補上 `Doc Target` 的讀取與新列留空規則。
- 共用 body 補上 `none` 的短路：跳過整段，不問不提案。
- 共用 body 調整段落順序，讓各端的能力陳述句**擋在**執行指令之前，而非在其後補救。
- 調和「此步驟 SHALL NOT 阻斷流程」與「說明後停下」——停的是這一步，不是整條流程。
- 調和三處無條件敘述與 `none` 跳過：`none` 時此步驟為 no-op。
- 移除 `workflow-concurrency` 中與自身單向指路互相矛盾的詢問時機斷言。
- 移除 body 中重複的內容邊界敘述（同一份檔案寫了兩次），壓縮 two-gates 段落。
- 統一新增 spec 段落的空行風格。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `workflow-instructions`: 調和團隊文件記錄步驟的非阻斷性與退化時的「停下」語意；補上 `Doc Target` 為 `none` 時此步驟為 no-op 的斷言。
- `workflow-concurrency`: 移除 registry spec 中屬於流程行為的詢問時機斷言，回歸單向指路。

## Impact

- `home/.chezmoitemplates/skills/dev-workflow.md`（step 2b 與 team-doc 段落）
- `openspec/specs/workflow-instructions/spec.md`、`openspec/specs/workflow-concurrency/spec.md`
- 兩端 name-map 不需改動——`teamDoc` / `teamDocGap` 已驗證兩端非空。
