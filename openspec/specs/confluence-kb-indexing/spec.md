# confluence-kb-indexing Specification

## Purpose
定義 `confluence-team-doc` skill 對**通用 KB**（跟單一專案無關、可複用的知識）的收納慣例：以 folder 08 的 KB 索引頁作為其 hub、`[KB][Topic]` 命名中的 `[Topic]` 作為分組鍵、子資料夾惰性升級，以及建立通用 KB 時登記到索引頁的 non-skippable 步驟。專案文件由 folder 07 的專案 hub 索引，不在此範圍。
## Requirements
### Requirement: 通用 KB 由專屬 KB 索引頁索引

`confluence-team-doc` skill 建立的**通用 `[KB]`**（跟單一專案無關、可複用的知識）SHALL 登記於 `shoalteritbev` 空間的 KB 索引頁（`🧠 Knowledge Base 索引`，page ID `5922357414`），作為通用 KB 的 hub。專案專屬 KB SHALL NOT 登記於此，而由其專案 hub（folder 07）索引。

#### Scenario: 建立通用 KB 後登記到索引頁

- **WHEN** skill 建立一頁通用 `[KB]`
- **THEN** 該頁 SHALL 在 KB 索引頁 `5922357414` 對應的 `[Topic]` `<h2>` 下新增一條連結
- **AND** 若該 `[Topic]` 分節尚不存在，SHALL 新增對應 `<h2>`
- **AND** 此步驟為 non-skippable，等同 workflow step 7 對專案 hub 的要求

#### Scenario: 專案 KB 不進通用索引

- **WHEN** 文件為專案專屬 KB（標題含專案名，或知識僅對該服務成立）
- **THEN** 該頁 SHALL 由其專案 hub 索引
- **AND** SHALL NOT 出現在 KB 索引頁

### Requirement: 通用 KB 以 [KB][Topic] 命名並惰性升級子資料夾

通用 KB 頁 SHALL 以 `[KB][Topic] Subject` 命名，`[Topic]`（第三方技術或領域）作為分組鍵。folder 08 SHALL 維持平堆，直到單一 `[Topic]` 累積約 5 頁以上，屆時 SHALL 將該 `[Topic]` 升級為 08 下的子資料夾。

#### Scenario: Topic 為分組鍵

- **WHEN** 新增通用 KB
- **THEN** 標題的 `[Topic]` bracket SHALL 對應 KB 索引頁的分組 `<h2>`
- **AND** 相同 `[Topic]` 的頁面在索引頁歸於同一 `<h2>`

#### Scenario: 惰性子資料夾升級

- **WHEN** 單一 `[Topic]` 的通用 KB 累積約 5 頁以上
- **THEN** 該 `[Topic]` SHALL 升級為 folder 08 下的子資料夾
- **AND** 少於此門檻時 SHALL 維持平堆，不預先開孤兒資料夾

### Requirement: skill 文件自足記載 KB 索引慣例

`confluence-team-doc` skill 的規範文件 SHALL 記載 KB 索引慣例，使任一 fresh agent 依 skill 即可正確執行，無需依賴 memory。

#### Scenario: SKILL 座標與 workflow 步驟涵蓋 KB 索引

- **WHEN** agent 依 skill 建立通用 KB
- **THEN** `SKILL.md` 的硬編座標 SHALL 含 KB 索引頁 page ID `5922357414`
- **AND** `references/workflow.md` step 7 SHALL 明列通用 KB → KB 索引頁的分支
- **AND** `references/doc-taxonomy.md` SHALL 記載 `[KB][Topic]` 命名與惰性子資料夾規則

