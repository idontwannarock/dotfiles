## 1. coordinate.md §定址:改成艦隊限定名 ＋ cwd 驗證

- [x] 1.1 §定址首段(承重規則)從「協調者的位址是名字(`coordinator`)」改為「位址是 `<fleet>-coordinator`,前綴是這支艦隊在開艦隊時選定的」,保留「不是 pane id」與換手讓名的那半
- [x] 1.2 補撞名的兩種發生方式(同時跑而撞、名字易主而改道)與缺陷形狀(靜默投遞到真實但錯誤的收件人,兩端都不報錯),並標明它屬於〈誰有資格說這句話〉同一族
- [x] 1.3 「接手後第一件事」三項清單:第 1 項從「`coordinator` 這個名字指著你自己」改為「`<fleet>-coordinator` 指著你自己,且前綴與 handoff 裡繼承來的那個相同」
- [x] 1.4 新增 cwd 歸屬驗證:投遞前 / 收報時兩端各要檢查什麼、不符時的處置;判準以 `git rev-parse --git-common-dir` 表述,不用字串前綴比對
- [x] 1.5 ~~把「不建機器層艦隊名冊」寫成〈定址〉節內的決定~~ **已被任務 6 取代**(判準保留,結論反轉)
- 驗證:`grep -n 'coordinator' home/.chezmoitemplates/skills/coordinate.md` 不再出現未帶前綴佔位的固定位址用法

## 2. coordinate.md 附錄 B:命名慣例

- [x] 2.1 「協調者固定叫 `coordinator`」改為前綴慣例,寫明前綴由人選、寫進 handoff 裁決、由接班者繼承
- [x] 2.2 明寫 32 字元上限如何被 `<fleet>-` 吃掉,給出 change 名稱的可用長度
- [x] 2.3 兩道 `herdr agent start` 範例與三層同名那道指令都套上前綴
- [x] 2.4 開艦隊時查一次 `agent list` 有沒有 `<prefix>-` 開頭的活 agent
- 驗證:附錄 B 的每個 `<name>` 佔位都看得出前綴從哪來

## 3. coordinate.md〈與 dev-workflow 的關係〉

- [x] 3.1 `:796` 那行的 `coordinator` 改為 `<fleet>-coordinator`
- [x] 3.2 補一句:位址隨派線訊息送達(與升級契約同一則),線不讀協調者的 handoff
- 驗證:與任務 4 的線側措辭一致

## 4. dev-workflow.md 線側契約(真正的發射點)

- [x] 4.1 `herdr agent prompt coordinator "..."` 改為位址由派線訊息帶來;派線訊息未給位址 = 派線壞了,當 fog 回報,不自行猜
- [x] 4.2 補投遞前的 cwd 歸屬檢查與不符時不投遞
- 驗證:`grep -n 'agent prompt coordinator' home/.chezmoitemplates/skills/dev-workflow.md` 無結果

## 5. 驗證與套用

- [x] 5.1 `bash tests/skill-name-map-axis.test.sh`(或該測試現行入口)——本次新增內容依「線的 kind」而定的部分要維持是表不是分支
- [x] 5.2 `chezmoi apply` **只套** `~/.claude/skills/coordinate`、`~/.claude/skills/dev-workflow`、`~/.codex/skills/coordinate` 三個子樹,不做全量
- [x] 5.3 讀回渲染後的檔案確認前綴措辭有落地(工具回報成功不等於它做了事)

## 6. 〈不要另建一份艦隊名冊〉改寫成〈鏡子 vs 帳本〉

- [ ] 6.1 判準保留(有沒有更新的權威來源),結論反轉:live 狀態不鏡像,**「該存在」必須自己記**
- [ ] 6.2 立論改建立在 herdr 答不出的那一格:`herdr agent` 無 history 子命令、名字在退出時清除,
      **已死的 session 與從未存在的完全無法區分**;herdr 只有「在」沒有「應該在」
- [ ] 6.3 前綴／cwd 那張正交表補進〈兩端都驗 cwd〉節首(目前只寫 cwd,把它講成艦隊判準不準確)
- 驗證:該節讀完答得出「什麼該記、什麼不該記」,而不是「不要記」

## 7. 艦隊名冊 `fleet.md`

- [ ] 7.1 欄位:名字、kind、cwd、開線旗標與角色、這條線是幹嘛的;**明文禁止** status／pane／進度／任數
- [ ] 7.2 差集偵測器那張三列表(名冊有/herdr 有 → 判讀與處置),含「原地重開」所需的最小集合
- [ ] 7.3 寫入時機限於派線(增列)與收尾(刪列);點明自我交接名字不變故一列都不用改
- [ ] 7.4 刪列掛進既有收尾清單(四訊號 ＋ 第五項編號回收 ＋ 第六項)
- 驗證:名冊欄位表與 `active_workflows.md` 欄位無重疊

## 8. 落點與資源池不變量

- [ ] 8.1 附錄 B／〈map〉標明艦隊產物落 `~/.agent/fleets/<repo-slug>/<fleet>/`,slug 用正典定義
- [ ] 8.2 寫明為何不與 `active_workflows.md` 混放(生命週期不同;拆艦隊 = 刪一個目錄)
- [ ] 8.3 寫入「一支艦隊必須完整擁有它所仲裁的稀缺資源池」,理由立在 domain 不在 cwd
- [ ] 8.4 合法例外(不同 base branch)＋ 但書(逐項判;migration 版號常仍是同一條序列)
- 驗證:全文找不到「一個 repo 只能有一支艦隊」這種寫法

## 9. map 的層級與對齊表斷點

- [ ] 9.1 開頭對齊表 `map issue → handoff` 改成「裂成 handoff ＋ map 兩個載體」,理由:拓撲不屬於任何一個 session
- [ ] 9.2 〈map〉節標明它是與艦隊同生同滅的工作面,不升進長青 context;殘留走既有晉升閘門
- [ ] 9.3 載體表從三格變四格(handoff／`active_workflows.md`／map／`fleet.md`)
- 驗證:`grep -n 'map' ` 全文,「map」不再同時指 handoff 與線間拓撲

## 10. 重新驗證與套用

- [ ] 10.1 `bash tests/skill-name-map-axis.test.sh`
- [ ] 10.2 `openspec validate coordinate-fleet-scoped-addressing`
- [ ] 10.3 `chezmoi apply` 只套四個 skill 子樹,再讀回渲染成品確認
