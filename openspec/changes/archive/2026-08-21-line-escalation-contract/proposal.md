## Why

被協調的線仍會在自己的 pane 開 `AskUserQuestion` 選單，把使用者拉進一個他不該盯著的地方。架構上決策應該回報給協調者，只有協調者決定不了才升級到真人——而真人只該跟協調者對話。

還有一個更硬的理由：**協調者根本無法回答那個選單。** `coordinate` 自己就寫著「多題選單一律不按鍵」（`tab`／方向鍵不會如預期換題，`enter` 會跳到 Submit 送出一份沒答完的答案）。所以線一旦開出多題選單，就進入一個**只有真人能解除、而真人不該盯著**的狀態——與 2026-08-21 那起「線空等一個永遠不會來的 enter」同形。

**但光關掉那個工具會更糟，這點已經實測。** 見 design.md 的 A/B 實驗：兩組都沒有發問工具，無契約那組仍然自己挑了版本號並宣告繼續，只在事後補一句風險提醒——**fog 被命名了，卻命名在預設值選定之後**，沒有擋住任何事。那正是本 skill 列為頭號失敗的〈把 fog 埋成合理預設〉。

## What Changes

- `coordinate`（協調者側）新增派線的機械做法：帶 `--disallowedTools AskUserQuestion`，**且同一次派工必須附上升級契約**。標明旗標範圍是單一 session、寫進設定檔會壞事、以及只有 Claude 有機械保障。
- `dev-workflow` 協調模式那節（線側）新增第四項義務：你沒有詢問使用者的工具；撞到做不了的決策 → 具名回報協調者並停下，**不要挑預設值**。

**BREAKING**：無。既有流程不變，只增派工參數與一條線側義務。

## Capabilities

### New Capabilities

(無)

### Modified Capabilities

- `discipline-skills`: `coordinate` 的行為契約新增派線參數與升級契約的綁定要求。
- `workflow-instructions`: 協調模式線側契約新增「無發問工具時的升級義務」。

## Impact

- `home/.chezmoitemplates/skills/coordinate.md`
- `home/.chezmoitemplates/skills/dev-workflow.md`
- `openspec/specs/discipline-skills/spec.md`、`openspec/specs/workflow-instructions/spec.md`
- 不影響任何 wrapper 或 name-map（不引入新 token）
