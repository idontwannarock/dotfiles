# model-invocability Specification

## Purpose
定義「哪些能力可以由模型自行啟動」的判準與其落點:以**可逆性與外部可見性**取代「有無副作用」,並記錄全部 Claude command 的分類結果、Codex 端無 gate 機制所造成的殘餘落差,以及禁止反向改動的依據。補足舊判準失去鑑別力後造成的分類漂移——同類能力散落在閘門兩側,而無人能說出判準是什麼。

## Requirements
### Requirement: 判準為可逆性與外部可見性

一個能力是否禁止模型自行啟動,SHALL 由兩個條件的 OR 決定:該操作**不可逆**,或其效果**外部可見**。滿足任一者的能力,Claude 端 wrapper SHALL 標記 `disable-model-invocation: true`;兩者皆不滿足者 SHALL NOT 標記。

SHALL NOT 以「是否有副作用」作為判準。該措辭無法區分風險量級相差一個數量級的操作,判準失去鑑別力後,同類能力會散落在閘門兩側。

#### Scenario: 本地且可回復的操作

- **WHEN** 某能力的效果僅限本機,且在 `.git` 或原始檔案存在的前提下可回復(如 `git commit`、`git rebase`、**新增**檔案到 `~/.agent/` 下)
- **THEN** SHALL NOT 標記 `disable-model-invocation`

#### Scenario: 版控之外路徑的破壞性操作

- **WHEN** 某能力會**移動或刪除**版控之外的檔案(如 `~/.agent/`、`~/.claude/` 下既有的檔案)
- **THEN** wrapper flag SHALL NOT 被當成該操作的把關 —— 那些路徑沒有 undo,把關責任在 skill body 自身的使用者確認步驟(見 `pickup` 的封存收尾)。判準管的是「能力能不能被自行啟動」,不是「啟動後可以做多毀滅性的事」

#### Scenario: 遠端寫入

- **WHEN** 某能力會寫入遠端或觸發外部系統(如寫 GitHub Issue comment、觸發 GitHub Actions workflow)
- **THEN** SHALL 標記 `disable-model-invocation: true`

#### Scenario: 可逆但外部可見

- **WHEN** 某能力的效果可撤銷,但撤銷前外部已能看到(如發出通知訊息後再撤回)
- **THEN** SHALL 標記 `disable-model-invocation: true` —— 兩個條件是 OR,可逆性不足以單獨放行

#### Scenario: 只讀能力

- **WHEN** 某能力不修改任何狀態(如唯讀的 code review)
- **THEN** SHALL NOT 標記 `disable-model-invocation` —— token 成本不是本判準涵蓋的風險,控制頻率的責任在 skill body 的觸發條件

### Requirement: 分類結果涵蓋全部 Claude command

`home/dot_claude/commands/` 下每一支 command SHALL 依上述判準分類,SHALL NOT 只處理在 Codex 端有對應能力的子集。判準是能力屬性而非 cross-tool parity 屬性。

鎖住的 command SHALL 僅有 `worklog-daily` 與 `worklog-team-status`。

#### Scenario: 解鎖清單

- **WHEN** 檢視 `handoff`、`pickup`、`handoff-list`、`arch-review`、`git/commit`、`git/sync`、`git/clean-gone`、`code/review-surgical`、`code/review-comprehensive`、`code/review-linus`、`code/review-uncommitted`、`code/review-security`、`code/review-spec`、`code/review-types`、`code/review-cross-model` 的 frontmatter
- **THEN** 皆 SHALL NOT 含 `disable-model-invocation`(共 15 支;`git/clean-gone` 刪除遠端已消失的本地分支,可經 reflog 回復,故屬可逆;`code/review-cross-model` 唯讀,其對外行為僅限於在本機 herdr pane 內起一個唯讀的 agent,無不可逆效果亦非外部可見)

#### Scenario: 清單涵蓋整棵樹

- **WHEN** 比對 `home/dot_claude/commands/` 下的檔案總數與上述兩份清單的總和
- **THEN** SHALL 相等 —— 清單是全稱斷言,任何一支未列出即為破口

#### Scenario: 鎖住清單

- **WHEN** 檢視 `worklog-daily` 與 `worklog-team-status` 的 frontmatter
- **THEN** 皆 SHALL 含 `disable-model-invocation: true`

#### Scenario: 無 Codex 對應者同樣適用

- **WHEN** 某 command 在 Codex 端無對應 skill(如 `code/review-security`、`code/review-spec`、`code/review-types`),因而不構成 parity 破洞
- **THEN** 仍 SHALL 依判準分類 —— 只處理有破洞者會留下同類破口

#### Scenario: 新增 command 時

- **WHEN** 新增任何 Claude command
- **THEN** SHALL 先依判準判定,再決定是否標記;SHALL NOT 沿用鄰近檔案的寫法作為預設

#### Scenario: 起用外部 agent 不改變分類

- **WHEN** 某能力會在本機起一個外部 agent(如 `code/review-cross-model` 經 herdr 派工)
- **THEN** 判準 SHALL 仍為該能力自身效果的可逆性與外部可見性 —— 被起用的 agent 若受唯讀邊界約束,SHALL NOT 因「啟動了另一個程序」而改判為需鎖

### Requirement: Codex 端不施加等效限制

Codex skill SHALL NOT 為了對齊而在 `description` 中加入「僅在使用者明確要求時使用」一類的措辭。Codex 無 command 概念亦無 gate 欄位,`description` 是提示而非關卡;加入軟性措辭會造成已施加限制的錯覺,而實際約束力無法驗證。

#### Scenario: 解鎖後兩端一致

- **WHEN** Claude 端移除 `disable-model-invocation` 後比較兩端
- **THEN** 兩端可呼叫性 SHALL 一致,SHALL NOT 需要在 Codex 端補任何限制措辭

#### Scenario: 仍鎖住者的殘餘不對稱

- **WHEN** `worklog-daily` 或 `worklog-team-status` 在 Claude 端鎖住而 Codex 端仍可自呼叫
- **THEN** SHALL 記為已知的平台能力落差,SHALL NOT 以 `description` 措辭掩蓋 —— 該落差源於 Codex 缺少 gate 機制,不是本 repo 的分類錯誤

### Requirement: 禁止反向改動

已解鎖的 command SHALL NOT 因「模型可以自行呼叫看起來不安全」而重新加上 `disable-model-invocation`。要重新鎖住,SHALL 先證明該能力滿足判準的任一條件。

#### Scenario: 看到 review 可被自行呼叫

- **WHEN** 有人發現模型能自行啟動 `code/review-*` 或 `arch-review`
- **THEN** SHALL NOT 逕行加回 flag —— 這些能力可逆且非外部可見,符合判準;若疑慮在 token 成本,SHALL 改動 skill body 的觸發條件

#### Scenario: 看到模型自行 commit

- **WHEN** 觀察到模型在使用者未要求時執行 commit
- **THEN** SHALL NOT 為 `git/commit` 加回 flag —— 該行為由系統提示層級的基線約束管轄,與 wrapper flag 是獨立兩層;加回 flag 只會使模型改用無護欄的預設路徑,失去 `git-commit` body 的敏感檔阻擋

### Requirement: commit trailer 不寫死模型型號

`home/.chezmoitemplates/skills/git-commit.md` 的 commit 訊息範本 SHALL 以「當前 model 的名稱」表達 `Co-Authored-By` 的值,SHALL NOT 寫死特定型號字面值。

#### Scenario: 換代不需改文件

- **WHEN** 執行環境的模型版本更新
- **THEN** 該範本 SHALL 無需修改即可產生正確的 trailer
