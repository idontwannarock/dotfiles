# project-context Specification

## Purpose
定義 repo-level 的長青專案 context:它是 repo root 的 `context/` OKF bundle,承載 domain 背景、詞彙與反覆適用的原則,供需求分析時查閱而非每 session 自動載入。規範其位置理由、依知識性質分檔的規則、四分法內容邊界(含 `docs/` 這一格)、auto-memory 與它的邊界,以及晉升閘門。格式規則見 `okf-bundle-conventions`。

## Requirements
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

`context/` 的內容 SHALL 遵循四分法邊界並受晉升閘門約束:`openspec/specs/` 存「系統做什麼」(WHAT、可驗收);change 的 `design.md` 存單一 change 的一次性方案選擇(隨 change archive);`docs/` 存操作步驟、故障排除,以及只解釋單一案例的理由;`context/` 存 domain 背景、詞彙表與**反覆適用的**長青原則。決策唯有上升為反覆適用的原則才 SHALL 被晉升進 `context/`,否則 SHALL 留在 archived `design.md`。

`docs/` SHALL NOT 承載可一般化的判斷依據。某段文字是否可一般化 SHALL 以下列測試判定,使結果不依賴個案判斷:

1. 讀者能照著這段文字操作嗎?能,且 `context/` 無對應條目 → 屬 `docs/`。能,但該步驟連同其理由已在 `context/` 有對應條目 → 視為重複,續行第 3 步。
2. 不能(它解釋的是為什麼)→ 換一個工具或情境,這段文字還成立嗎?不成立 → 只解釋單一案例,屬 `docs/`。
3. 仍成立 → 屬 `context/`。`context/` 已有對應條目時,`docs/` 端 SHALL 移除該段並改以指路;尚無對應條目時,SHALL 依「非 sync/archive 階段不得寫入」以候選標記記入 `design.md`。

上述三步的根判準是:同一事實若改變,需要同步修改的檔案數 SHALL 為一。任一步的判定若使某事實同時存在於 `docs/` 與 `context/`,以此根判準覆蓋之。

`docs/` 亦 SHALL NOT 承載已凍結、不再維護的設計或計畫記錄。這類記錄 SHALL 置於 `openspec/changes/archive/`,與其他歷史並存。判準是問「這份文件描述的是現在還成立的東西,還是當時怎麼想的」——後者屬 archive。凍結記錄 SHALL NOT 因歸檔而被改寫內容;其內部失效的相對連結屬記錄的一部分,SHALL NOT 逐條修補。

指路 SHALL 以檔案層級為粒度(每份受影響的文件一行,指向 `context/`),SHALL NOT 逐處連結至 `context/` 的個別條目標題 —— 條目措辭變動會使該類連結失效。

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

#### Scenario: 操作步驟留在 docs

- **WHEN** 某段文字是讀者可照著執行的操作步驟或故障排除,且 `context/` 無對應條目
- **THEN** 它 SHALL 留在 `docs/`,SHALL NOT 搬入 `context/`

#### Scenario: 操作步驟已在 context 有對應條目時仍屬重複

- **WHEN** 某段文字雖可照著執行,但該步驟連同其理由已在 `context/` 有對應條目
- **THEN** `docs/` SHALL 移除該段並改以指路,不因其可操作而豁免

#### Scenario: 單一案例的理由留在 docs

- **WHEN** 某段文字解釋為什麼,但換一個工具或情境即不成立
- **THEN** 它 SHALL 留在 `docs/`,SHALL NOT 搬入 `context/`

#### Scenario: 可一般化的判斷依據不留在 docs

- **WHEN** `docs/` 下某段文字解釋為什麼,且換一個工具或情境仍成立,而 `context/` 已有對應條目
- **THEN** `docs/` SHALL 移除該段,並於該文件加一行指向 `context/` 的指路

#### Scenario: 凍結的歷史記錄不留在 docs

- **WHEN** 某份文件描述的是當時怎麼想(設計記錄、實作計畫),且已不再維護
- **THEN** 它 SHALL 置於 `openspec/changes/archive/`,SHALL NOT 留在 `docs/`

#### Scenario: 歸檔不改寫記錄內容

- **WHEN** 將凍結記錄移入 `openspec/changes/archive/`
- **THEN** 其內容 SHALL 維持原樣,失效的內部相對連結 SHALL NOT 被逐條修補
- **AND** 該記錄當時不存在的 artifact SHALL NOT 被補寫

### Requirement: auto-memory 不承載 repo-level 長青知識

agent 的 auto-memory(`~/.claude/memory/<repo-slug>/`)SHALL NOT 作為 repo-level 長青知識的唯一載體。凡某條事實同時滿足「以本 repo 為範圍」與「跨 change 反覆適用」,它 SHALL 於 `openspec-sync-specs`／archive 階段被晉升進 `context/` 下性質相符的 concept 檔,並於晉升後回收該 memory。

理由是載體性質而非內容品質:auto-memory 是 point-in-time 觀察、不受版控、不在需求分析的閱讀路徑上,且無人審閱。同一條事實留在那裡會隨程式碼漂移而無從察覺,也不會被 `grill`／`arch-review` 讀到。

回收 SHALL 同時刪除 memory 檔與 `MEMORY.md` 中對應的索引行。只刪其一會留下斷鏈:索引指向不存在的檔案,或孤兒檔案不再可被發現。

memory 若在晉升後**仍有**未被 `context/` 涵蓋的唯一內容,SHALL 保留該檔並僅刪除已晉升的部分;整份刪除的前提是無唯一內容。

#### Scenario: repo-level 長青事實只存在於 auto-memory

- **WHEN** 某條事實以本 repo 為範圍、跨 change 反覆適用,且僅記載於 auto-memory
- **THEN** 它 SHALL 於 sync/archive 階段被晉升進 `context/` 下性質相符的 concept 檔

#### Scenario: 晉升後回收 memory

- **WHEN** 某份 memory 的內容已全數被 `context/` 涵蓋
- **THEN** 該 memory 檔 SHALL 被刪除
- **AND** `MEMORY.md` 中對應的索引行 SHALL 於同一次操作中一併刪除

#### Scenario: memory 尚有未涵蓋內容

- **WHEN** 某份 memory 僅部分內容被晉升進 `context/`
- **THEN** 該檔 SHALL 保留,SHALL NOT 因部分晉升而整份刪除
- **AND** 已晉升的那部分 SHALL 自該檔移除,以免同一事實存在兩處

#### Scenario: 非 repo-level 的知識不晉升

- **WHEN** 某條 memory 記載的是使用者偏好、跨 repo 的工作習慣,或僅對當次對話有意義的狀態
- **THEN** 它 SHALL 留在 auto-memory,SHALL NOT 進 `context/`
