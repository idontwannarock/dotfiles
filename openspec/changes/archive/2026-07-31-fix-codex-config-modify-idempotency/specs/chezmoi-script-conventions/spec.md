## ADDED Requirements

### Requirement: 產生設定檔的腳本 SHALL 為不動點

凡是以既有目標檔內容作為輸入、並產出該檔新內容的腳本（`modify_*`，以及在 Windows 代其職責的 `run_after_*` shim），SHALL 為不動點：把自己的輸出再餵回自己，結果 SHALL 逐位元組相同。

此需求與既有的安裝腳本冪等條文是不同性質：安裝腳本的冪等是守衛式（已達標則跳過動作），本需求是輸出穩定性——輸出的形狀 SHALL NOT 取決於輸入中不具語意的部分（如區塊之間的空行數量）。

自既有檔案取回保留區塊時，SHALL 丟棄該區塊尾端的空行，由腳本自身決定區塊之間的分隔，使分隔符不會與被保留內容重複累加。

#### Scenario: 輸出再餵回自己不變

- **WHEN** 以任一輸入執行腳本得到輸出 O，再以 O 作為輸入執行同一腳本得到 O'
- **THEN** O 與 O' 逐位元組相同

#### Scenario: 已累積雜訊的輸入一次收斂

- **WHEN** 輸入為前述缺陷累積出的檔案（保留區塊與後續區塊之間有 N 個多餘空行，N 任意大）
- **THEN** 單次執行即產出正規形式，且該結果滿足前一個 scenario

#### Scenario: 保留區塊的實質內容不因修剪而遺失

- **WHEN** 輸入含多個 `[projects.*]` 區塊，區塊之間夾有空行
- **THEN** 所有 `[projects.*]` 的鍵值與區塊間的空行原樣保留，僅最後一個區塊尾端的空行被丟棄

### Requirement: 跨平台雙源實作 SHALL 保持同步

當一份設定檔因 interpreter 派發限制而必須由兩支腳本各自實作（Unix 的 `modify_*` 與 Windows 的 `run_after_*.ps1.tmpl` shim），兩者 SHALL 產出語意相同的結果。刻意的平台差異 SHALL 於原始碼中標註其理由，未標註的差異即視為漂移。

兩支腳本內以字面文字同步的區段（全域設定、`instructions`、MCP server 清單）SHALL 逐字一致，唯經標註的平台差異除外。

`instructions` 中引用的 skill 名稱 SHALL 實際存在於 source 中。

#### Scenario: 同步區段逐字一致

- **WHEN** 比對兩支腳本的全域設定與 `instructions` 區段
- **THEN** 內容逐字相同

#### Scenario: 平台差異帶理由

- **WHEN** 兩支腳本的 MCP server 定義存在差異（例：Windows 的 `npx` 需 `cmd /c` 包裝）
- **THEN** 該差異在原始碼中有一行說明其平台成因

#### Scenario: 引用的 skill 存在

- **WHEN** 於 source 中搜尋 `instructions` 提到的每個 skill 名稱
- **THEN** 該 skill 在 `home/.chezmoitemplates/skills/` 或各工具的 skills 目錄下實際存在
