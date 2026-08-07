## Why

現行 `reviewFull`(大型流程的 review 關卡)的六個 lens 與 confidence 打分全部由同一個模型家族執行,多樣性只發生在 prompt 層:模型先驗與盲點是共享的,而每個 lens 看到的證據又都由主 agent 挑選並餵入。結果是沒有任何機制挑戰 reviewer —— 同源盲點造成的**漏看**,現行關卡在結構上抓不到。

herdr 的 agent 控制介面使「派工給另一種 kind 的 agent 並等它收斂」成為可用的一級操作,讓跨模型的獨立蒐證與交叉反駁第一次具備可自動化的形狀。

## What Changes

- 新增一個唯讀的跨模型 adversarial review 能力:在獨立 pane 起一個 **kind 與當前工具不同**的 agent,只給它 branch/commit range 與 repo 路徑,由它自行蒐證並產出 findings;隨後雙方互換 findings 各做一輪反駁。
- 該能力掛進**大型流程**的 review 關卡(`code:review-comprehensive` 之後),小型流程不掛;同時提供可獨立呼叫的入口。
- findings 的分級改由跨模型結果決定:兩邊都存活 → Critical;僅單邊存活 → 明列為分歧,交由使用者裁決。現行 confidence 打分保留,但職責收斂為**噪音過濾**,不再兼任分級。
- 前置條件不滿足時軟退化,但報告 SHALL 顯式標註「未執行 + 原因」。
- 收尾為強制要求:確認 agent 收斂 → 關閉 pane → 驗證無殘留,成功與失敗路徑皆適用。

## Capabilities

### New Capabilities
- `cross-model-review`: 跨模型 adversarial review 的行為契約 —— 跨工具部署形狀、派工對象的選擇規則、給予的上下文邊界、唯讀邊界、一輪交叉反駁、分級與分歧呈現、退化可見性、以及 agent/pane 的生命週期收尾。

### Modified Capabilities
- `workflow-instructions`: 「大型核心流程」的步驟串與「Code review 必做」的大型流程 scenario 納入跨模型 review 步驟;小型流程明確不納入。
- `model-invocability`: 新增的 Claude command 必須進入分類清單 —— 該 spec 的「清單涵蓋整棵樹」為全稱斷言,任何未列出的 command 即為破口。本能力唯讀、可逆、非外部可見,故歸入解鎖清單。

## Impact

- **新增**:`home/.chezmoitemplates/skills/<name>.md`(shared body)、Claude 端 command wrapper、Codex 端 skill wrapper。
- **修改**:`home/.chezmoitemplates/skills/review-comprehensive.md`(接上跨模型步驟、調整分級來源)、`home/.chezmoitemplates/skills/dev-workflow.md` 的大型流程串、`docs/` 對應文件。
- **外部依賴**:herdr binary 與 `HERDR_ENV=1`;對造 agent 的 CLI 需已安裝並登入。兩者皆為選配 —— 缺任一者走軟退化,SHALL NOT 成為大型流程的硬阻斷點。
- **不影響**:小型流程、`discipline-skills`(本能力自帶部署形狀 requirement,比照 `arch-review` 先例)、既有六個 lens 的內容。
