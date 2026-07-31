## ADDED Requirements

### Requirement: repo-level project context 為 repo root 的 OKF bundle

本 repo SHALL 於 repo root 的 `context/` 維護一個長青、人可讀、model-agnostic 的專案 context,供「未來需求分析」進入狀況使用。該目錄 SHALL 為一個 OKF v0.2 bundle,其格式 SHALL 遵循 `okf-bundle-conventions`。

其位置 SHALL NOT 在 `openspec/` 之下:OpenSpec CLI 不讀寫此內容,置於其下會誤示為 CLI 契約的一部分。其位置亦 SHALL NOT 在 `.chezmoiroot` 所指的 source root 之內 —— 這份 context 是本 repo 專屬的,不部署到任何機器。

其關注點 SHALL 有別於 `CLAUDE.md`／`AGENTS.md`:後者是給 AI 工具每 session 固定載入的操作性指令;`context/` 是需求／domain 知識,於需要時查閱,SHALL NOT 被接進任一工具的自動載入路徑。

#### Scenario: bundle 存在且位置正確

- **WHEN** 檢查 repo
- **THEN** `context/index.md` SHALL 存在且帶 `okf_version: "0.2"`
- **AND** `openspec/project.md` SHALL NOT 存在

#### Scenario: 需求分析時作為背景

- **WHEN** 進行需求分析(grill 或 openspec-new-change)
- **THEN** `context/` 下的內容 SHALL 可作為 domain 背景被讀取,以免重讀整份程式碼或掃過 archived changes 才能取得一致認知

#### Scenario: 不自動載入

- **WHEN** 任一 AI 工具開啟 session
- **THEN** `context/` SHALL NOT 被自動注入 prompt;讀取 SHALL 由需要它的 skill 主動發起

### Requirement: 內容依知識性質分檔

`context/` 下的內容 SHALL 依知識性質分入具名 concept 檔,每個檔承載單一性質(專案概述、詞彙、反覆適用原則、能力分組等),使讀者可只讀需要的一份。SHALL NOT 以單一大檔承載全部性質。

指向 `openspec/specs/` 的能力分組 SHALL 以**分組與各組邊界**為主體,SHALL NOT 逐一列舉 spec 名稱 —— 逐項列舉會隨 spec 增減而漂移,且可由 `openspec spec list` 產生;分組則不可由檔案系統推導。

#### Scenario: 單一性質單一檔案

- **WHEN** 新增一段 project context
- **THEN** SHALL 置於性質相符的既有 concept 檔,或建立新的具名 concept 檔
- **AND** SHALL NOT 因缺乏歸屬而置於 `index.md`

#### Scenario: 能力分組不列舉 spec 名

- **WHEN** `openspec/specs/` 下新增或移除一個 capability 且其歸屬落在既有分組內
- **THEN** `context/` 下的能力分組檔 SHALL NOT 需要修改

### Requirement: 內容邊界與晉升閘門

`context/` 的內容 SHALL 遵循三分法邊界並受晉升閘門約束:`openspec/specs/` 存「系統做什麼」(WHAT、可驗收);change 的 `design.md` 存單一 change 的一次性方案選擇(隨 change archive);`context/` 存 domain 背景、詞彙表與**反覆適用的**長青原則。決策唯有上升為反覆適用的原則才 SHALL 被晉升進 `context/`,否則 SHALL 留在 archived `design.md`。

晉升 SHALL 只發生於 `openspec-sync-specs`／archive 階段,以確保每一條晉升內容都有已 ship 的實作背書。

#### Scenario: WHAT 不進 context

- **WHEN** 某內容是可驗收的行為要求(WHAT)
- **THEN** 它 SHALL 留在 `openspec/specs/`,SHALL NOT 複製進 `context/`

#### Scenario: 一次性決策不晉升

- **WHEN** 某決策只適用於當次 change
- **THEN** 它 SHALL 留在該 change 的 `design.md` 隨 archive,SHALL NOT 進 `context/`

#### Scenario: 反覆適用原則晉升

- **WHEN** 某決策上升為跨 change 反覆適用的原則,或為新的 domain 概念／詞彙
- **THEN** 它 SHALL 於 sync/archive 階段被提煉進 `context/` 下性質相符的 concept 檔

#### Scenario: 非 sync/archive 階段不得寫入

- **WHEN** grill、arch-review 或實作階段發現疑似長青的內容
- **THEN** SHALL 以候選標記記入 `design.md`,SHALL NOT 直接寫入 `context/`
