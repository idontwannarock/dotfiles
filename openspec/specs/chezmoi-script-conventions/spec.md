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
