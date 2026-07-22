# project-context-doc Specification

## Purpose
TBD - created by archiving change add-project-context-doc. Update Purpose after archive.
## Requirements
### Requirement: project.md 為長青專案 context
`openspec/project.md` SHALL 作為長青、人可讀、model-agnostic 的專案 context 文件,供「未來需求分析」進入狀況使用。其關注點 SHALL 有別於 `CLAUDE.md`/`AGENTS.md`:後者是給 AI 工具每 session 固定載入的操作性指令;`project.md` 是需求/domain 知識,於需要時查閱。

#### Scenario: 文件存在
- **WHEN** 檢查 repo
- **THEN** `openspec/project.md` SHALL 存在,且內容為人可讀的 markdown、不綁單一工具

#### Scenario: 需求分析時作為背景
- **WHEN** 進行需求分析(grill 或 openspec-new-change)
- **THEN** `project.md`(若存在)SHALL 可作為 domain 背景被讀取,以免重讀整份程式碼或掃過 archived changes 才能取得一致認知

### Requirement: 內容邊界與晉升閘門
`project.md` 的內容 SHALL 遵循三分法邊界並受晉升閘門約束:`openspec/specs/` 存「系統做什麼」(WHAT、可驗收);change 的 `design.md` 存單一 change 的一次性方案選擇(隨 change archive);`project.md` 存 domain 背景、詞彙表與**反覆適用的**長青原則。決策唯有上升為反覆適用的原則才 SHALL 被晉升進 `project.md`,否則 SHALL 留在 archived `design.md`。

#### Scenario: WHAT 不進 project.md
- **WHEN** 某內容是可驗收的行為要求(WHAT)
- **THEN** 它 SHALL 留在 `openspec/specs/`,SHALL NOT 複製進 `project.md`

#### Scenario: 一次性決策不晉升
- **WHEN** 某決策只適用於當次 change
- **THEN** 它 SHALL 留在該 change 的 `design.md` 隨 archive,SHALL NOT 進 `project.md`

#### Scenario: 反覆適用原則晉升
- **WHEN** 某決策上升為跨 change 反覆適用的原則,或為新的 domain 概念/詞彙
- **THEN** 它 SHALL 被提煉進 `project.md`

