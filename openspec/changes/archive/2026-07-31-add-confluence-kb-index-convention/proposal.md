## Why

`confluence-team-doc` skill 用「專案 hub」（folder 07）索引各專案文件，但**通用 KB（folder 08、跟單一專案無關的可複用知識）沒有對應的 hub**。`references/workflow.md` step 7 只更新專案 hub，遇到通用 KB 就靜默跳過，導致 folder 08 淪為無索引的平堆，混雜通用 KB、專案 KB、legacy 筆記；數量一多即難以尋找。

執行面已先行處理：在 `shoalteritbev` 空間手動建立 KB 索引頁（`🧠 Knowledge Base 索引`，page ID `5922357414`，parent = folder 08 `5552996508`）並收攏現有通用 KB。本變更把這個收納慣例烘進 skill，讓後續建立通用 KB 時**非跳過地**登記到索引頁，收斂 folder 08 的擴張。

## What Changes

- `SKILL.md`：Hardcoded coordinates 區登記 KB 索引頁 `5922357414`；orchestration step 7 標籤改為涵蓋 KB 索引；Common mistakes 增列「通用 KB 未登記到索引」。
- `references/workflow.md`：step 7 由「更新專案 hub」推廣為「更新索引：專案 hub 或 KB 索引」，新增通用 KB → KB 索引頁的 non-skippable 分支；step 2 補通用 KB 路由；section-mapping 區分專案 KB 與通用 KB。
- `references/doc-taxonomy.md`：`[KB] topic scope` 段落補「登記到 KB 索引頁、`[Topic]` 為分組鍵、同 topic 約 5 頁升級子資料夾（惰性）」規則。
- `references/page-anatomy.md`：新增 KB 索引頁版型（anatomy）小節。

## Capabilities

### New Capabilities

- `confluence-kb-indexing`：通用 KB 的收納慣例 —— KB 索引頁作為通用 KB 的 hub、`[KB][Topic]` 命名為分組鍵、惰性子資料夾升級，以及建立通用 KB 時登記到索引頁的 non-skippable 步驟。

### Modified Capabilities

（無既有 spec 涵蓋 `confluence-team-doc` skill 行為；現行 specs 未涉及。）

## Impact

- **修改檔案**：`home/dot_claude/skills/confluence-team-doc/SKILL.md`、`references/workflow.md`、`references/doc-taxonomy.md`、`references/page-anatomy.md`。
- 純 skill 文件變更，無程式碼、無 chezmoi template 邏輯變更；`chezmoi apply` 僅重新部署這幾份 `.md` 到 `~/.claude/skills/confluence-team-doc/`。跨平台行為一致。
- **前置已完成**：KB 索引頁（`5922357414`）已建立並收攏現有通用 KB —— 本變更只把慣例文件化，不需再動 Confluence。
- **Follow-up（不屬本變更，另行追蹤）**：既有頁面改名/重分類，見 `tasks.md` §5 附註。
