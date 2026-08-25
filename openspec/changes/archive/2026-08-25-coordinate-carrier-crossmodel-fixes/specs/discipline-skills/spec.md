## MODIFIED Requirements

### Requirement: coordinate 線間訊息的載體
`coordinate` SHALL 規定線與線之間(含協調者與線雙向)的每一則往來要選一個載體,判準 SHALL 以「這則內容要在對方的**哪個時刻**生效」為軸,SHALL NOT 改以「是資料還是指令」為軸。判準 SHALL 有**三格**,SHALL NOT 只有二選一。

#### Scenario: 線側契約與協調者側在機械判準上逐字對齊
- **WHEN** 任何機械判準(觸發字元集、長度門檻、建檔機制、檔名形狀)同時出現在協調者 skill 與線側契約
- **THEN** 兩份 SHALL 逐字一致,且**兩處都 SHALL 標注這是複寫、另一半在哪**
- **AND** 理由 SHALL 是:線**不載入**協調者的 skill,所以只改一份時,**沒被改到的那份正好是唯一會被執行的那份**
- **AND** SHALL 收錄實例:觸發字元集移除「括號」時只改了協調者那份,線側仍列著它,於是該次修正在實際生效的位置上等於沒發生

#### Scenario: create-only 機制也要送到線那邊
- **WHEN** 線被要求以「建檔而非覆寫」的方式寫訊息
- **THEN** 線側契約 SHALL 給出**機制**(寫入前檢查存在並中止,或等價的獨佔建檔),SHALL NOT 只給散文規則
- **AND** 理由 SHALL 是:重導向與寫檔工具**預設就會覆寫**,而 `~/.agent/` 不在版控裡

#### Scenario: 路徑安全要逐元件宣稱
- **WHEN** skill 主張「訊息只帶路徑就沒有那些字元」
- **THEN** SHALL 逐元件說明各自的約束:`<topic>` 限定字元集、`<ts>` **SHALL 有指定格式**、`<repo-slug>` 由所選 slug 派別的轉換保證
- **AND** SHALL NOT 從「`<topic>` 已約束」推論「整條路徑安全」
- **AND** SHALL 保留一個機械手段作為最後一道(送出前以單引號包住整個路徑)

#### Scenario: 通知失敗留下的 orphan 要有出口
- **WHEN** 檔案已寫成功而通知送不出去
- **THEN** SHALL 二選一:換管道重送,或**把該則降級為第二格**(寫進對方將來找得到的地方,下次接觸時帶出)
- **AND** SHALL NOT 允許就這樣放著——**對寄件者看起來像已完成**,而收訊方推導不出路徑、永遠不會去看
- **AND** SHALL 寫明定序規則解決的是先後,不是這個殘留態

#### Scenario: 第二格的內容要被一個活得比它久的索引指到
- **WHEN** 內容落在第二格(未來才生效),而其典型讀者**尚未開工**
- **THEN** 該內容 SHALL 同時被一個長命索引指到(handoff 的段落、memory、或交給接班人的清單)
- **AND** 理由 SHALL 是:落點目錄**沒有索引**,而收件人不存在時無人可通知——**「檔案活下來」與「將來有人找得到」是兩件事**
- **AND** SHALL NOT 以「檔案在那裡」作為該格已完成的判準

#### Scenario: 線的接班人也要讀 `msgs/`
- **WHEN** 一條線交接,接班人上任
- **THEN** 接手清單 SHALL 要求它讀 `msgs/` 裡發給這個名字的內容,SHALL NOT 把該項標為只有協調者要做
- **AND** 理由 SHALL 是:**裁決與合併後的跨線事實正是寫給線的**,而引用義務掛在「下一則回報」上——若交接發生在那則回報之前,接班人不知道有裁決存在

### Requirement: coordinate 艦隊產物的落點
`coordinate` SHALL 規定艦隊產物(名冊、map 與**線間訊息**)落在 `~/.agent/fleets/<repo-slug>/<fleet>/`,SHALL NOT 與 `active_workflows.md` 混放於同一目錄。`<repo-slug>` SHALL 採用既有的正典 repo slug 定義,SHALL NOT 另立一套。線間訊息 SHALL 落在該目錄下的 `msgs/` 子目錄。

#### Scenario: `<repo-slug>` 要明確選派,不得假設兩派同鍵
- **WHEN** skill 指定 `<repo-slug>` 的導出方式
- **THEN** SHALL 明確選定一個 slugify 派別並寫出理由,SHALL NOT 寫成「與 handoff、workflow 狀態同一個 key」
- **AND** 選擇 SHALL 是 handoff 家族(`:` `\` `/` `.` 皆換為 `-`),理由 SHALL 是收線時 `msgs/` 的搬移目的地正是 handoff 的 `attachments/`——**不同派會讓兩者互相找不到**
- **AND** SHALL 引用既有的 repo-identity 參考文件並寫明該處尚未收斂,新機制 **SHALL NOT 假設兩派產生同一個 key**
- **AND** SHALL 寫明失敗形狀:路徑含點的 repo 上,兩個協調者導出不同目錄,**交接看起來像「沒有名冊也沒有訊息」,而兩者都寫成功了**

#### Scenario: 拆艦隊清單的邊界是「有沒有被掃過」,不是「屬於誰」
- **WHEN** 拆艦隊清單說明它涵蓋什麼
- **THEN** 引導句 SHALL 以「**逐線收尾掃不到的**」為判準,SHALL NOT 以「不屬於任何單一線的」為判準
- **AND** 理由 SHALL 是:意外死亡的線留下的訊息**屬於**某條線,卻從未被任何收尾掃過;以歸屬為邊界的引導句會讓字面讀者漏掉正是最容易遺失的那一列
- **AND** SHALL 寫明判準從屬性換成事件:**這份清單防的是「那個事件沒發生」**

### Requirement: coordinate 傳訊管道分兩層
`coordinate` SHALL 把跨 agent 傳訊寫成兩層:結構上免疫於吃字與 append 的管道,與仍然適用全部吃字機制的退路。退路那一節 SHALL NOT 被刪除。**縮小該節的適用範圍 SHALL NOT 被視為刪除**,兩者 SHALL 明確區分。

#### Scenario: 反對 `"$(cat file)"` 的理由不得含假命題
- **WHEN** skill 說明為什麼不要把檔案內容代換回訊息裡
- **THEN** 理由 SHALL 限於三項:內容仍整段送進對方 context、檔案沒有指定落點與生命週期、與 file-as-carrier 直接矛盾
- **AND** SHALL NOT 宣稱該寫法會讓內容「照樣經過 shell」——**command substitution 的輸出不會被再次展開**,該命題為假
- **AND** skill SHALL 記下這個形狀:**結論正確而其中一個理由為假,方向正確反而讓它更難被發現**
