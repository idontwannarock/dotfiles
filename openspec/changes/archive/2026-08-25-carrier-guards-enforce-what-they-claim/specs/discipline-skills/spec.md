## MODIFIED Requirements

### Requirement: coordinate 位置指涉要有守衛
`coordinate` 的分類成員 SHALL 以**內容**命名,SHALL NOT 以位置序號指涉。該禁令的範圍 SHALL NOT 限於收尾清單——載體同樣適用,且載體比收尾清單**更**不穩定:收尾清單的序號至少印得出來,而載體表原本連編號都沒印。該禁令 SHALL 由測試施加,SHALL NOT 只以措辭宣稱。

#### Scenario: 位置指涉由測試擋下
- **WHEN** 有人在 skill body 或 spec 裡寫下「第N項」或「第N格」
- **THEN** `tests/carrier-positional-reference.test.sh` SHALL 轉紅,SHALL NOT 只靠散文告誡
- **AND** 禁止的字元集 SHALL 涵蓋 Arabic 數字、超過十的數、大小寫變體,英文側 SHALL 涵蓋線側契約實際使用的名詞(`carrier`),SHALL NOT 只涵蓋 `kind`——`kind` 在該檔另有 agent kind 的意思,而 `carrier` 才是改名後的用詞
- **AND** 母體 SHALL 明文宣告,豁免 SHALL 逐條寫理由,理由 SHALL NOT 為純空白
- **AND** 豁免 SHALL 綁**它所豁免的那個 token**,SHALL NOT 豁免整行。該行其餘命中 SHALL 照舊轉紅
- **AND** 理由 SHALL 是:一行同時帶著合法豁免與另一個真違規,是這族最可能發生的形狀——合法帶標記的行正是規則說明行,而那種行日後最常被加上新的子句
- **AND** 行尾判定 SHALL 容忍尾隨空白(markdown 的兩空格換行會讓合法豁免誤紅),且標記之後 SHALL NOT 允許另一個 HTML 註解
- **AND** 規則自述(引用「第五項」作為反例的那句)SHALL 豁免,理由 SHALL 是那是 mention 不是 use <!-- positional-ref: 第五項: 規則自述，引它作為反例來定義豁免本身，是 mention 不是 use -->

#### Scenario: 帶遞進語意的分層不在禁令範圍
- **WHEN** 判斷「第①層」「第四層」這類序號是否違反本禁令
- **THEN** SHALL NOT 列入禁止字元集,理由 SHALL 是那些序號**帶遞進語意**(第①層比第②層更基礎),與純位置指涉不同族
- **AND** SHALL NOT 為一個沒有實例的風險擴大禁令——換來的是一份會不斷變長的豁免清單,而長豁免清單本身就是規則拓寬了的徵兆

#### Scenario: 章節交叉引用要解析得到
- **WHEN** skill body 以 `〈X〉` 指涉同檔的某一節
- **THEN** `tests/coordinate-section-xref.test.sh` SHALL 驗證 `X` 是同檔某個標題的**子字串**,SHALL NOT 要求等值
- **AND** 比對 SHALL 針對**原始文字**而非渲染後的文字,理由 SHALL 是引用與標題兩邊都可能帶模板語法
- **AND** 指向本檔以外的目標(handoff 檔、內文標記)SHALL 逐條豁免並寫明指向何處
- **AND** 豁免 SHALL 以**出現位置**(檔案＋名字)為鍵,SHALL NOT 以名字全域比對——否則為一處外部指涉給的豁免會永久豁免整棵樹裡同名的每一處

#### Scenario: 兩份 body 的機械判準由測試同步
- **WHEN** 任何機械判準同時出現在協調者 skill 與線側契約
- **THEN** `tests/carrier-contract-sync.test.sh` SHALL 比對兩份的**門檻值、觸發字元集、以及規則指名的來源與目的載體**,SHALL NOT 比對措辭——兩份用不同語言撰寫,比對措辭必然誤報
- **AND** 觸發字元 SHALL 以**帶界定符**的形狀偵測(如帶反引號的 `` `$` ``),SHALL NOT 在整個窗裡搜尋裸的單一字元——`$` 與 `!` 在模板與散文裡到處都是,裸搜尋讓「移除一個觸發字元」被同窗的一句散文掩蓋
- **AND** 該測試 SHALL 以「改一側 → 證明另一側轉紅 → 改回」實際驗證,SHALL NOT 以推理代替

#### Scenario: 守衛的母體與 CI 觸發路徑要同時改
- **WHEN** 一支守衛測試的母體納入一個新的檔案或目錄
- **THEN** CI 的觸發路徑 SHALL 同步涵蓋該路徑
- **AND** 理由 SHALL 是:只改母體不改觸發路徑,做出來的是一支**只在別的檔案被改時才跑**的測試——它對只改該檔的 PR 永遠沉默,而那正是唯一需要它出聲的 PR
- **AND** SHALL 寫明這種錯法沒有任何測試抓得到,因為它就是測試本身

## ADDED Requirements

### Requirement: coordinate 守衛要有一層斷言自己輸出的檢查
穩態為零匹配的守衛,它的回報路徑在健康 repo 上**從不執行**。`coordinate` 的守衛 SHALL 有一層拿 fixture 跑整支腳本、斷言它**說了什麼**的檢查,SHALL NOT 只斷言判別式,也 SHALL NOT 只斷言它轉紅。

#### Scenario: 判別式檢查擋不住回報路徑的缺陷
- **WHEN** 一支守衛的正常狀態是零匹配
- **THEN** SHALL 有一層 fixture 檢查,以已知的違規／豁免／乾淨三種輸入跑整支腳本
- **AND** 該層 SHALL 斷言違規的那一行被點名、**豁免的那一行不被點名**、以及建議文字有出現
- **AND** 理由 SHALL 是:把「違規」改判成「豁免」這種一行變更,會讓判別式的每一條斷言照樣通過而整支測試印綠

#### Scenario: 宣稱了保證卻不提供保證的檢查要移除
- **WHEN** 一段檢查在任何情況下都不會觸發(如把 `find` 的離開碼當成 `grep` 的)
- **THEN** SHALL 移除它,SHALL NOT 留著並加註解說明它的限制
- **AND** 理由 SHALL 是:一盞永遠不亮的燈會讓讀者以為那一族已經有人看著

### Requirement: coordinate 多直譯器覆蓋要驗證 harness 真的換了
宣稱「在兩個直譯器下都跑過」時,SHALL 確認**執行測試的那個程式**換了,SHALL NOT 只把直譯器名字傳進環境變數。

#### Scenario: 迴圈變數換了值不等於直譯器換了
- **WHEN** CI 以迴圈跑多個直譯器
- **THEN** harness SHALL 以該直譯器執行測試檔本身
- **AND** 理由 SHALL 是:只把名字傳進環境變數而 harness 寫死,不讀該變數的測試會被同一個直譯器跑兩遍,而 job log 顯示兩行綠
