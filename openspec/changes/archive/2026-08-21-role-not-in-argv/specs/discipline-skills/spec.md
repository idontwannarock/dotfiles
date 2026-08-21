## ADDED Requirements

### Requirement: coordinate 角色不在 argv 裡
`coordinate` SHALL 寫明「掃描各 session 的啟動參數以確認分佈正確」這個檢查**答不了它要問的問題**,並 SHALL 要求開線時把 argv **與角色**一起落檔。

#### Scenario: 三態使分母不可知
- **WHEN** 有人要以掃描啟動參數的方式確認「該關的都關了、該留的都留了」
- **THEN** skill SHALL 列出三態(被派出的線、協調者、**不屬於任何艦隊的 session**)並標明**三者都無法從 argv 分辨**
- **AND** SHALL 指明這是〈證據的資格〉第一層的實例——旗標欄位對「協調者」與「路人」給同一個答案,因此沒有資格區分兩者

#### Scenario: 落檔要含角色
- **WHEN** 開一條線或開接班協調者
- **THEN** SHALL 把 argv **與該 session 的角色**一起落檔——argv 記得了旗標卻記不得角色

#### Scenario: 實測敘述不得誇大為一次成功的稽核
- **WHEN** skill 引用某次掃描結果作為軼事
- **THEN** SHALL 標明該結論只涵蓋角色已知的那些 session,SHALL NOT 寫成「分佈全對」——否則下一個人會以為那個查法可行

### Requirement: coordinate 命名三層各自獨立
`coordinate` SHALL 標明 herdr 定址名與 agent 自身的 display name 是**各自獨立設定**的,SHALL NOT 讓讀者以為一道指令同時決定三層。

#### Scenario: 少了 display name 旗標仍有定址名
- **WHEN** 一個 session 啟動時未帶設定 display name 的旗標
- **THEN** skill SHALL 說明它在 herdr 清單裡**仍然有名字**,因為定址名來自改名指令
- **AND** 一行讓三層同名的寫法 SHALL 被標明為便利而非機制
