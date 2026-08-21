## ADDED Requirements

### Requirement: coordinate 接班協調者必須驗自己的發問能力
`coordinate` SHALL 要求接手的協調者在**接手後第一件事**就驗證自己手上有沒有直接詢問真人的能力,SHALL NOT 等到需要用它的時候才發現。

關閉發問管道的旗標 SHALL NOT 被帶進開接班協調者的那道指令——那道指令與派線用的是同一道,而範圍正確(單一 session)不代表套對了 session。

#### Scenario: 範圍太寬與套錯 session 是兩種形狀
- **WHEN** skill 描述關閉發問管道的風險
- **THEN** SHALL 分開寫兩種失效:**範圍太寬**(寫進設定檔,所有 session 一起被關)與**套錯 session**(範圍正確,但那個 session 是接班的協調者)
- **AND** SHALL NOT 合成一條——前者的動作是「不要那樣寫」,後者的動作是「開完之後去驗」

#### Scenario: 防線放在接班人身上而非前任身上
- **WHEN** 決定這條規則寫在哪一節
- **THEN** SHALL 以「接手後第一件事」為承重位置——讀者是接班人本人,且它是唯一能實際驗證的人
- **AND** 前任那側 SHALL 也寫一句,但 SHALL NOT 只寫在那裡:前任可能正在收尾、context 將滿,或根本不是它開的

#### Scenario: 接手後的檢查要是清單
- **WHEN** skill 描述接手後第一件事
- **THEN** SHALL 以逐條清單呈現,至少含:名字指著自己、**手上有沒有發問工具**、廣播一次
- **AND** SHALL NOT 寫成「確認一切正常」這種無法逐條核對的句子

#### Scenario: 沒有那個工具時的處置
- **WHEN** 接班協調者發現自己沒有發問能力
- **THEN** SHALL 立刻說出來,並 SHALL 請使用者重開一個未帶該旗標的 session——那是啟動旗標,跑到一半補不回來
- **AND** SHALL NOT 自行繞過或以預設值繼續——那正是本 skill 的頭號失敗

#### Scenario: 這一條不設機械守衛
- **WHEN** 有人提議自動檢查某個 session 有哪些工具
- **THEN** SHALL NOT 加——從外部查不到某個 pane 的 agent 手上有哪些 tool,唯一能驗的是該 session 自己

#### Scenario: 對名字提問得到的答案只對當下有效
- **WHEN** 協調者以名字向另一個角色(如 `coordinator`)提問其當下狀態
- **THEN** SHALL 把時間或 pane 釘住,或明確接受該答案只對當下有效——名字不是 session,同一個問題在不同時刻問會得到不同任的答案,而回答者不會提醒提問者
