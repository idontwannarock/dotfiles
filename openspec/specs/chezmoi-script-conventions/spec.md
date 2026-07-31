# chezmoi-script-conventions Specification

## Purpose
定義 chezmoi `run_*` 腳本的撰寫契約：runtime log 結構（起訖 banner 由單一來源產生、段落印出目的、早退與失敗都要收尾）、共用邏輯抽取到 `.chezmoitemplates/scripts/` 的門檻，以及「合併腳本」與「抽取 fragment」的判準。`modify_*` 腳本明確排除於 log 契約之外。這些條文由 `chezmoi-author` skill 承載。
## Requirements
### Requirement: run_* 腳本 SHALL 印出起始與結束 banner

每支部署到 chezmoi source root 的 `run_*` 腳本 SHALL 在開始時印出一行起始 banner、結束時印出一行結束 banner。兩者的標題文字 SHALL 來自單一來源（起始時記錄、結束時取用），使起訖標題在結構上不可能不一致。

結束 banner SHALL 標示執行結果（成功或失敗與其 exit code）。

`modify_*` 腳本 SHALL NOT 適用本需求 —— 其 stdout 即為目標檔案內容，額外輸出會污染檔案。

#### Scenario: 正常執行印出成對 banner
- **WHEN** 任一 `run_*` 腳本完整執行至結尾
- **THEN** 輸出的第一行為 `=== BEGIN <title> ===`，最後一行為 `=== END <title> (ok) ===`，兩處 `<title>` 逐字相同

#### Scenario: 早退路徑仍印出結束 banner
- **WHEN** 腳本因冪等守衛命中而提前結束（bash `exit 0` / PowerShell `return`）
- **THEN** 仍印出 `=== END <title> (ok) ===`，輸出不會看起來像被截斷

#### Scenario: 失敗時結束 banner 標示 exit code
- **WHEN** bash 腳本在 `set -e` 下因命令失敗而中止，exit code 為 N（N ≠ 0）
- **THEN** 印出 `=== END <title> (FAILED rc=N) ===`

#### Scenario: modify_ 腳本不含 banner
- **WHEN** 檢查任一 `modify_*` 腳本
- **THEN** 該腳本不呼叫任何 banner 輸出，stdout 僅含目標檔案內容

### Requirement: 腳本段落 SHALL 於 runtime 印出其目的

腳本內每個邏輯段落 SHALL 於執行時印出一行說明該段落**目的**的訊息，而非僅以原始碼註解標示。目的描述 SHALL 說明「這段在做什麼／為什麼」，而非僅給出段落編號或代號。

#### Scenario: 段落目的出現在 apply 輸出
- **WHEN** `chezmoi apply` 執行一支含多個段落的腳本
- **THEN** 每個段落開始時輸出一行 `--- <purpose>`，使讀者不看原始碼即可知道當前進度

#### Scenario: 目的描述不是代號
- **WHEN** 檢查段落輸出內容
- **THEN** 輸出為可讀的目的敘述（例：`--- 移除 docker：CLI 已改由 chezmoi-external 提供`），而非 `--- (2)` 或 `--- section 2` 這類代號

### Requirement: log 動詞集 SHALL 跨 interpreter 語意對齊

系統 SHALL 提供一組共用 log 動詞，bash 與 PowerShell 兩種 interpreter 各一份實作，且兩者輸出格式逐字一致。動詞集 SHALL 涵蓋：開始（begin）、段落目的（section）、實際動作（step）、冪等跳過（skip）、非致命警告（warn）、結束（end）。

實作 SHALL 置於 `home/.chezmoitemplates/scripts/` 並以 `{{ template }}` 於渲染期內嵌，SHALL NOT 依賴 runtime 檔案存在。

#### Scenario: 兩個 interpreter 產出相同格式
- **WHEN** bash 腳本呼叫 section 動詞、PowerShell 腳本呼叫對應動詞，傳入相同字串
- **THEN** 兩者輸出的該行文字逐字相同

#### Scenario: fragment 於渲染期內嵌
- **WHEN** 對引用 log fragment 的腳本執行 `chezmoi execute-template`
- **THEN** 渲染結果直接含有 log 函式定義，執行時不需讀取任何外部檔案

#### Scenario: log fragment 與嚴格模式相容
- **WHEN** bash 腳本在 `set -euo pipefail` 下引用 log fragment
- **THEN** fragment 不因未設定變數而觸發錯誤，結束 banner 仍正常印出

### Requirement: 重複邏輯 SHALL 抽為 .chezmoitemplates/scripts/ fragment

同一 interpreter 內出現 2 次以上的相同邏輯 SHALL 抽取為 `home/.chezmoitemplates/scripts/` 下的 fragment，並由各腳本以 `{{ template }}` 引用。fragment 檔名 SHALL 以副檔名標示其 interpreter（`.sh` / `.ps1`），使同名雙版本可並存。

#### Scenario: 冪等安裝守衛不重複定義
- **WHEN** 檢查所有 `run_*.sh.tmpl` 腳本
- **THEN** npm 全域套件的冪等安裝守衛僅在 `scripts/npm-install.sh` 定義一次，各腳本以 `{{ template }}` 引用

#### Scenario: fragment 檔名帶 interpreter 副檔名
- **WHEN** 同一功能需要 bash 與 PowerShell 兩版
- **THEN** 兩個 fragment 分別命名為 `<name>.sh` 與 `<name>.ps1`

### Requirement: 相同形狀只差資料的腳本 SHALL 合併為單一腳本加資料表

當多支腳本的控制流在抽掉資料後逐字相同，系統 SHALL 將其合併為單一腳本，差異以資料表表達。反之，含有各自獨特邏輯的腳本 SHALL 各自保留，僅共用 fragment。

判準 SHALL 為：把差異抽成表之後，剩餘控制流是否逐字相同；合併後是否需要用旗標或分支重新把它們拆開。

#### Scenario: 純資料差異的腳本被合併
- **WHEN** 多支腳本除了一個套件清單之外內容完全相同
- **THEN** 合併為一支腳本，套件清單成為該腳本內的資料表

#### Scenario: 含獨特邏輯的腳本不被合併
- **WHEN** 腳本除共通部分外另含專屬的環境變數改寫或註冊邏輯
- **THEN** 該腳本保留為獨立檔案，僅將共通部分改為引用 fragment

#### Scenario: 資料表的理由欄位餵給段落目的
- **WHEN** 合併後的腳本逐項處理資料表
- **THEN** 表中該項的「理由」欄位被印為該段落的目的，原本埋在檔頭註解的資訊成為 apply 時可見的輸出

### Requirement: chezmoi-author skill SHALL 承載上述慣例

`home/.chezmoitemplates/skills/chezmoi-author.md` SHALL 包含 log 契約與 fragment 抽取判準兩節，且其 Authoring Checklist SHALL 含對應檢查項，使新增腳本時能被提示遵循。

#### Scenario: skill 含 log 契約
- **WHEN** 讀取 chezmoi-author skill 內容
- **THEN** 其中定義了六個 log 動詞、起訖 banner 規則、以及早退仍須收尾的要求

#### Scenario: skill 含抽取與合併判準
- **WHEN** 讀取 chezmoi-author skill 內容
- **THEN** 其中說明何時抽 fragment、何時合併腳本，並給出兩者的判準

#### Scenario: checklist 涵蓋新慣例
- **WHEN** 依 skill 的 Authoring Checklist 逐項檢查一支新腳本
- **THEN** checklist 會問到「是否有成對 banner」「段落目的是否 runtime 可見」「重複邏輯是否已抽 fragment」

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

