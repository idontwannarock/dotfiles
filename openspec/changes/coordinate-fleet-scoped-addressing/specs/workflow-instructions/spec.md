## MODIFIED Requirements

### Requirement: 協調模式下的線側契約
當一條線是由協調者派出的多條平行線之一時,`dev-workflow` 的核心流程 SHALL 不變,但 SHALL 附加三項義務。完整規則屬於 `coordinate`;`dev-workflow` 內文 SHALL 只放**線側**契約,並以 name-map 指向該 skill,SHALL NOT 寫死 skill 名。

#### Scenario: 以名字定址協調者
- **WHEN** 一條線要回報給協調者
- **THEN** SHALL 以名字定址,SHALL NOT 以 pane id 定址——pane id 在換手時會變,名字不會
- **AND** 該名字 SHALL 來自**派線訊息**,SHALL NOT 是內文寫死的固定字串——herdr 名稱是全機扁平命名空間,固定字串會把回報靜默投給別支艦隊的協調者
- **AND** 派線訊息未給位址時,線 SHALL 當作 fog 回報,SHALL NOT 自行猜一個名字

#### Scenario: 投遞前驗收件人的艦隊歸屬
- **WHEN** 線要送出回報
- **THEN** SHALL 先確認該名字的 `cwd` 落在自己所屬的 repo 工作樹範圍內
- **AND** 不符時 SHALL NOT 投遞——這是位址過期或派線訊息有誤時唯一攔得住誤投的檢查

#### Scenario: 跨線事實即時回報
- **WHEN** 線撞到任何別條線也可能動到的東西(共用 fixture、兩條線都斷言的量測、migration 版本、編號區間、落在兩者影響半徑內的檔案)
- **THEN** SHALL 立即回報,SHALL NOT 等到收尾——自己量到的數字只對自己量測時的 base 成立,而合併那些數字的只有協調者

#### Scenario: 前提錯誤的裁決應被推翻
- **WHEN** 協調者給的裁決其問題框架本身不成立
- **THEN** 線 SHALL 指出框架不對,SHALL NOT 只在給定選項內作答——只在框內作答會把協調者的錯誤放大成決策;同理 SHALL 拒絕會汙染自身證據的指令(例如在自己 session 裡執行會打斷當前回合的實驗)
