## Why

`coordinate` 線與線之間的回報目前全走 `herdr agent prompt <name> "<長文>"`。大段訊息會洗掉雙方 session 的內容,而這是最輕的一項代價——真正硬的有三個:

1. **長訊息只活在 context window 裡。** 壓縮後剩摘要,且查不到漏了什麼。這對本 skill 特別要命,因為它自己就規定「接手包含重驗你要繼承的結論」,**而重驗需要原文**。
2. **吃字整族**。`herdr agent prompt` 的內容經過 shell,skill 裡有一整節在講反引號／`$`／heredoc 三個機制(2026-08-21 一天三起,其中一起是協調者在寫「怎麼避免吃字」那則廣播時自己被吃了)。訊息只帶路徑就沒有那些字元。
3. **它同時是「這件事確實發生過」的證據**,與 `context/principles.md` 既有那條「資料通道不得是螢幕輸出。以檔案為通道、以 pane 為 trigger」同一條,只是推廣到線與線之間。

⚠️ **省 context 這個動機比想像中弱,不要拿它當立論**:對方仍要把檔案讀進 context,同樣的 token。真正省到的只有「選擇性讀」「晚點讀」「根本不用讀」三種情況。

**而 skill 裡已經有半條規則在做這件事**,只是它答錯了一格。〈交付物不要留在會消失的地方〉末段的「訊息 vs 檔案」表以**「什麼時候生效」**為軸:未來生效 → 檔案,現在要知道 → 訊息。**跨線事實坐在這張表答錯的那一格**——它現在就要對方知道,但它是資料、且未來要能重讀。表把它判給訊息,於是本 skill「唯一無法外包的工作」那一整節的產出,全部走在會被壓縮掉的載體上。

## What Changes

- **判準軸不變,新增第三形態。** 保留「什麼時候生效」這個軸(它承重的軼事全部依賴時間軸),但承認有一格是**兩者皆是**:現在就要知道、且未來要能重讀。該格載體是**寫檔 ＋ 帶摘要的 prompt**,不是二選一。**跨線事實明文歸入這一格。**
- **一條機械升級規則,兩個觸發條件。** 純訊息含反引號／`$`／`!`／括號,**或**超過 **5 行或 500 字元** → 自動升為第三形態。這是守衛不是告誡——吃字一族的告誡已有實測敗績。
- **落點與生命週期。** 線間訊息落 `~/.agent/fleets/<repo-slug>/<fleet>/msgs/`,與艦隊同生同滅;**收線時把該活過艦隊的搬出去**,〈收尾〉清單新增該項。
- **一則一檔**,`<ts>-<from>-<to>-<topic>.md`,動作是**建檔不是覆寫**。
- **不設回執。** 要確認對方接住了 → **查它的產物**,不要問它。裁決類訊息要求對方在下一則**本來就要發的**回報裡引用該訊息檔名。
- 附錄 A〈訊息內容會經過一層 shell〉**縮範圍但不刪除**:它現在只管純訊息那一格。
- `dev-workflow` 線側契約同步收錄本協定。**這不是選擇是必然**:spec 既有條文明寫「沒有任何機制會讓實作線載入 coordinate skill」,不寫在那裡,線收不到協定,而失敗是靜默的。

## Capabilities

### New Capabilities

(無)

### Modified Capabilities

- `discipline-skills`:新增〈coordinate 線間訊息的載體〉requirement(三形態、升級規則、一則一檔、不設回執);修改〈coordinate 艦隊產物的落點〉納入 `msgs/` 與收線搬移;〈coordinate 傳訊管道分兩層〉新增 scenario 釘死**縮範圍 ≠ 刪除退路**(該條現行明寫 `SHALL NOT 被刪除`)。

## Impact

- `home/.chezmoitemplates/skills/coordinate.md` —— 〈交付物不要留在會消失的地方〉末段判準表、〈跨線事實〉歸屬、〈收尾〉清單、附錄 A 吃字那節的範圍、附錄 B 落點
- `home/.chezmoitemplates/skills/dev-workflow.md` —— coordinated mode 線側契約
- `openspec/specs/discipline-skills/spec.md` —— 上列三條 requirement
- 部署面:兩份 body 經 name-map 渲染到 Claude 與 Codex,`sh tests/skill-name-map-axis.test.sh` 為把關測試
- 不影響:`fleet.md` 名冊欄位、`map.md` 格子、`active_workflows.md`、艦隊命名與定址
