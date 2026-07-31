## MODIFIED Requirements

### Requirement: 內容邊界與晉升閘門

`context/` 的內容 SHALL 遵循四分法邊界並受晉升閘門約束:`openspec/specs/` 存「系統做什麼」(WHAT、可驗收);change 的 `design.md` 存單一 change 的一次性方案選擇(隨 change archive);`docs/` 存操作步驟、故障排除,以及只解釋單一案例的理由;`context/` 存 domain 背景、詞彙表與**反覆適用的**長青原則。決策唯有上升為反覆適用的原則才 SHALL 被晉升進 `context/`,否則 SHALL 留在 archived `design.md`。

`docs/` SHALL NOT 承載可一般化的判斷依據。某段文字是否可一般化 SHALL 以下列測試判定,使結果不依賴個案判斷:

1. 讀者能照著這段文字操作嗎?能,且 `context/` 無對應條目 → 屬 `docs/`。能,但該步驟連同其理由已在 `context/` 有對應條目 → 視為重複,續行第 3 步。
2. 不能(它解釋的是為什麼)→ 換一個工具或情境,這段文字還成立嗎?不成立 → 只解釋單一案例,屬 `docs/`。
3. 仍成立 → 屬 `context/`。`context/` 已有對應條目時,`docs/` 端 SHALL 移除該段並改以指路;尚無對應條目時,SHALL 依「非 sync/archive 階段不得寫入」以候選標記記入 `design.md`。

上述三步的根判準是:同一事實若改變,需要同步修改的檔案數 SHALL 為一。任一步的判定若使某事實同時存在於 `docs/` 與 `context/`,以此根判準覆蓋之。

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
