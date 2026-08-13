## Why

`confluence-team-doc` skill 已能建立 ARCH / RUNBOOK 頁並處理交叉連結，但 `dev-workflow` 從頭到尾沒提過它。要不要寫、什麼時候寫，全靠當下想不想得到，於是實際會寫的只有「剛好記得」的那幾次。

缺的不是能力，是**判準**。沒有判準只會退化成兩個壞結果之一：每次都問（很快被學會跳過，而「被學會忽略的 gate 比沒有 gate 更糟」），或每次都不問（等於沒加）。

## What Changes

- `dev-workflow` 的**大型與小型兩個流程**，在 review 迴圈收斂後、`finish-branch` 之前，新增一個選用的 Confluence 記錄步驟。
- 判準綁「repo 外有沒有讀者」，**不綁 diff 大小**，因此兩個流程一視同仁。
- `~/.agent/workflow-registry.md` 新增 `Doc Target` 欄，承載 repo 級的三態綁定（未問過 / hub / 明確不需要），採 lazy 詢問。
- 釘住 registry 列「只增不減」的不變量——否則新欄位會被未來的清理動作靜默抹掉。
- 兩處顯性退化：Codex 端無 Atlassian MCP、Doc Target 指向非 `shoalteritbev` 空間。

不做的事：不動 `confluence-team-doc` 的 `shoalteritbev` 硬編碼座標，不修 registry 既有的欄名與 slug drift。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `workflow-instructions`: 大型與小型核心流程的步驟串各新增一個 Confluence 記錄步驟；新增該步驟的觸發判準、決定權歸屬與退化行為的 requirement。
- `workflow-concurrency`: Workflow Registry 格式新增 `Doc Target` 欄並定義其三態語義與寫入時機；新增 registry 列只增不減的不變量。

## Impact

- `home/.chezmoitemplates/skills/dev-workflow.md`（共用 body）
- `home/dot_claude/skills/dev-workflow/SKILL.md.tmpl`、`home/dot_codex/skills/dev-workflow/SKILL.md.tmpl`（兩端 name-map，漏加 token 會渲染成空字串）
- `openspec/specs/workflow-instructions/spec.md`、`openspec/specs/workflow-concurrency/spec.md`
- `~/.agent/workflow-registry.md`：per-machine 資料檔，不在版控內；新欄位由流程在需要時補寫，不做批次遷移。
- `confluence-team-doc` skill 本身不修改，僅被引用。
