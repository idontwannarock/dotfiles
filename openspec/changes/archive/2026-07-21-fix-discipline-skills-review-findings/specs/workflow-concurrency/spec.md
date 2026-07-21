# workflow-concurrency

## MODIFIED Requirements

### Requirement: Active Workflows Index
每個 repo 的 project memory 下 SHALL 有 `active_workflows.md`,記錄該 repo 所有進行中的 OpenSpec 流程。Current Step 欄位 SHALL 使用 tool-neutral 的語義標籤(如 `apply-change done`、`review`),SHALL NOT 寫入任何工具專屬的 sigil'd skill token — 此檔案跨工具共用,恢復工作的工具依自身 name-map 重新推導 token。

#### Scenario: 流程步驟推進
- **WHEN** 每個 skill 完成時
- **THEN** Claude SHALL 更新該流程的 current step(tool-neutral 標籤)和 last updated
