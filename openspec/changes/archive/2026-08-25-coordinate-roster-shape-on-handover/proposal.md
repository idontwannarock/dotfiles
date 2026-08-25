## Why

`coordinate` 艦隊名冊有一條規則與它自己記的欄位互相矛盾。名冊要求只記「session 被換掉時不會變的東西」——含 **agent kind** 與**開線旗標**——但同一條 requirement 的最後一個 scenario 寫「一條線自我交接時名冊 SHALL NOT 需要任何修改，因為名字沒變」。名字確實沒變，可是接班者若以不同的 kind 或不同的旗標開出來，那一列的 kind 與旗標欄就是舊的。而名冊的用途正是「依這一列把不見的那個原地重開」——拿舊的形狀重開，得到的是一條**名字完全正常、啟動形狀卻不對**的線。這與同一條 requirement 已寫明的〈拿過期落點重開 → 在錯的工作樹上開出一條名字完全正常的線〉是同一個形狀，只是換一格欄位。

查證時發現**第二處、更硬的矛盾**：附錄 B 要求「開完接班協調者之後，把它的 `cmdline` ＋ 角色寫進 `fleet.md` 那一列」。那是一次**發生在交接時的名冊寫入**，直接違反同一條 requirement 的「寫入 SHALL 只發生在派線與收尾」。根因是 `cmdline` 屬 per-process 事實，process 一換就變——名冊記它，等於在帳本裡塞了一格鏡子。

## What Changes

- **交接必須同形狀**：交接 ＝ 照名冊那一列的 kind ＋ 旗標原地重開，啟動形狀不得變。要換形狀就不是交接，是「這條線收掉、協調者重新派一條」，走既有的派線寫入時機。
- **規則課給前任**：前任 SHALL 在讓出名字前把自己的 kind ＋ 該不該帶旗標寫進交接文件，並明訂接班者 SHALL 以同形狀開出來。事後稽核在此結構上不可行，只能在開線那一刻防。
- **BREAKING（對 skill 使用者的行為契約）**：名冊那一格從記 `cmdline` 字串改為記**啟動形狀**（kind ＋ 角色 ＋ 該不該帶旗標）。交接時名冊零寫入，〈寫入只有派線與收尾兩個時機〉第一次真的成立。
- **接班者上任自檢**：線在交接後上任 SHALL 執行與協調者對稱的自檢（查自己的 cmdline，比對名冊那一列的形狀），不符則具名回報，SHALL NOT 自行繞過或改設定檔。
- 修正〈寫入時機限於派線與收尾〉那個 scenario 的立論：從「名字沒變」換成「形狀不得變」。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `discipline-skills`：〈coordinate 艦隊名冊〉這條 requirement 的欄位清單與最後一個 scenario；新增交接同形狀、前任交代義務、接班者自檢三項行為要求。

## Impact

- `openspec/specs/discipline-skills/spec.md` —— 〈coordinate 艦隊名冊〉requirement
- `home/.chezmoitemplates/skills/coordinate.md` —— 名冊段落（`:88`～`:118`）、〈接手後第一件事〉（`:130`）、附錄 B 開接班協調者那段（`:1146`）
- 部署面：該 body 經 name-map 渲染到 Claude 與 Codex 兩端，`sh tests/skill-name-map-axis.test.sh` 為把關測試
- 不影響：`map.md`、`active_workflows.md`、艦隊產物落點
