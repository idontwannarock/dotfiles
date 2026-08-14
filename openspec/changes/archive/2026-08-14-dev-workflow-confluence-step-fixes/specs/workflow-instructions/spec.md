## MODIFIED Requirements

### Requirement: 團隊文件記錄步驟
兩個核心流程 SHALL 在 review 迴圈收斂之後、`finish-branch` 之前，套用一條判準決定本次 change 是否應寫入團隊文件；判定為是時 SHALL 交由 `confluence-team-doc` 執行。此步驟 SHALL NOT 阻斷流程——任何退化、跳過或使用者否決，SHALL 一律以繼續執行 `finish-branch` 收場。

判準為單一問句：**repo 外的人若要回答這次產出的那個問題（怎麼操作 / 為什麼這樣設計），除了讀這份 diff 之外有沒有別的地方可讀？沒有 → 值得寫。** 判準 SHALL 綁「repo 外是否有讀者」，SHALL NOT 綁 diff 大小或流程規模。

當該 repo 的 `Doc Target` 為 `none` 時，此步驟 SHALL 為 no-op。引用此步驟的流程敘述 SHALL NOT 各自複製這項例外——例外由本 requirement 單處持有。

文件型別（ARCH / RUNBOOK / KB）的決定 SHALL 交由 `confluence-team-doc` 的 `doc-taxonomy` 規則，SHALL NOT 在流程說明中重述。

#### Scenario: 判定值得寫
- **WHEN** 本次 change 產出了 repo 外的人需要照著操作的程序，或會被 repo 外的人追問「為什麼這樣設計」的決策
- **THEN** Claude SHALL 提出寫入提案，包含判定理由與建議標題
- **AND** 是否寫入 SHALL 由使用者拍板

#### Scenario: 判定不值得寫
- **WHEN** 本次 change 的產出只有 repo 內的讀者（例如調整 skill 措辭、重構內部腳本）
- **THEN** Claude SHALL 直接進入 `finish-branch`
- **AND** SHALL NOT 輸出任何負面判定的說明——例行化的「本次不需要」提示會使此關卡被學會忽略

#### Scenario: 小型 change 仍可觸發
- **WHEN** 一個僅數行的 change 產出了別的團隊要照著操作的程序
- **THEN** Claude SHALL 判定值得寫
- **AND** SHALL NOT 以 change 規模小為由跳過

#### Scenario: 使用者否決
- **WHEN** Claude 提出寫入提案而使用者否決
- **THEN** Claude SHALL 直接進入 `finish-branch`，SHALL NOT 追問

#### Scenario: Doc Target 為 none 時此步驟為 no-op
- **WHEN** 流程抵達此步驟而該 repo 的 `Doc Target` 為 `none`
- **THEN** Claude SHALL 直接進入 `finish-branch`，SHALL NOT 套用判準、SHALL NOT 詢問、SHALL NOT 提案
- **AND** 流程敘述中「SHALL 套用判準」的措辭 SHALL 理解為受此例外限定，SHALL NOT 據以認定衝突

### Requirement: 團隊文件目標的 lazy 詢問
流程 SHALL 於既有的 registry 讀取步驟一併讀取該 repo 的 `Doc Target`，但 SHALL NOT 於該時點詢問使用者。詢問 SHALL 延遲到判準判定值得寫的那一刻。流程說明中執行 registry 讀取的那一步 SHALL 明列 `Doc Target` 為讀取項目之一，並 SHALL 於新增 registry 列時明示該欄留空——否則此 requirement 無可執行的依據。

#### Scenario: Doc Target 為空白且本次值得寫
- **WHEN** 判準判定值得寫，而該 repo 的 `Doc Target` 為空白
- **THEN** Claude SHALL 於此時詢問該 repo 的團隊文件目標（hub 頁，或明確不需要）
- **AND** SHALL 將答覆寫回 registry

#### Scenario: Doc Target 為 none
- **WHEN** 該 repo 的 `Doc Target` 為 `none`
- **THEN** Claude SHALL 跳過整個團隊文件步驟，SHALL NOT 詢問、SHALL NOT 提案

#### Scenario: 流程開始時不詢問
- **WHEN** 流程於 registry 讀取步驟發現 `Doc Target` 為空白
- **THEN** Claude SHALL 繼續流程，SHALL NOT 於此時詢問使用者

#### Scenario: 讀取步驟涵蓋 Doc Target
- **WHEN** 流程執行 registry 讀取步驟
- **THEN** 該步驟的說明 SHALL 將 `Doc Target` 列為讀取項目
- **AND** 該步驟新增 registry 列時 SHALL 產出 `Doc Target` 欄並留空

### Requirement: 團隊文件步驟的顯性退化
當執行前提不滿足時，此步驟 SHALL 明說原因並停下該步驟，SHALL NOT 靜默消失，亦 SHALL NOT 停下整條流程。各端能力與目標支援度的陳述 SHALL 出現在它所限制的執行指令**之前**，SHALL NOT 置於其後。

#### Scenario: 工具端無 Atlassian MCP
- **WHEN** 當前工具端沒有可用的 Atlassian MCP（例如 Codex 端）
- **THEN** 流程說明 SHALL 仍呈現此步驟的存在，並明說本端無對應能力、需於具備該能力的工具端執行
- **AND** SHALL NOT 以條件式渲染讓此步驟在該端整段消失

#### Scenario: 目標為尚未支援的 space
- **WHEN** `Doc Target` 指向 `confluence-team-doc` 尚未支援的 Confluence space
- **THEN** Claude SHALL 明說該 space 尚未支援、需先泛化 `confluence-team-doc` 的座標
- **AND** SHALL NOT 嘗試以團隊 space 的座標寫入其他 space
- **AND** SHALL 繼續執行 `finish-branch`，SHALL NOT 停在該步驟

#### Scenario: 能力陳述先於執行指令
- **WHEN** 流程說明同時包含「交給 `confluence-team-doc` 執行」與「本端是否具備該能力」兩項敘述
- **THEN** 能力敘述 SHALL 排在執行指令之前
- **AND** SHALL NOT 讓渲染後的順序變成先下達指令、後才否定其可行性
