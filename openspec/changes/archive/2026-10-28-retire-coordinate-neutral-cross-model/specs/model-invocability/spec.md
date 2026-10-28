## MODIFIED Requirements

### Requirement: 分類結果涵蓋全部 Claude command

`home/dot_claude/commands/` 下每一支 command SHALL 依上述判準分類,SHALL NOT 只處理在 Codex 端有對應能力的子集。判準是能力屬性而非 cross-tool parity 屬性。

鎖住的 command SHALL 僅有 `worklog-daily` 與 `worklog-team-status`。

#### Scenario: 解鎖清單

- **WHEN** 檢視 `handoff`、`pickup`、`handoff-list`、`git/commit`、`code/review-surgical`、`code/review-comprehensive`、`code/review-cross-model`、`code/review-architecture` 的 frontmatter
- **THEN** 皆 SHALL NOT 含 `disable-model-invocation`(共 8 支;`code/review-cross-model` 唯讀,其對外行為僅限於在本機 agent 多工器(herdr pane 或 Ghostex session)內起一個唯讀的 agent,無不可逆效果亦非外部可見;`code/review-architecture` 只診斷不改 source)

#### Scenario: 清單涵蓋整棵樹

- **WHEN** 比對 `home/dot_claude/commands/` 下的檔案總數與上述兩份清單的總和
- **THEN** SHALL 相等 —— 清單是全稱斷言,任何一支未列出即為破口

#### Scenario: 鎖住清單

- **WHEN** 檢視 `worklog-daily` 與 `worklog-team-status` 的 frontmatter
- **THEN** 皆 SHALL 含 `disable-model-invocation: true`

#### Scenario: 無 Codex 對應者同樣適用

- **WHEN** 某 command 在 Codex 端無對應 skill,因而不構成 parity 破洞
- **THEN** 仍 SHALL 依判準分類 —— 只處理有破洞者會留下同類破口

#### Scenario: 新增 command 時

- **WHEN** 新增任何 Claude command
- **THEN** SHALL 先依判準判定,再決定是否標記;SHALL NOT 沿用鄰近檔案的寫法作為預設

#### Scenario: 起用外部 agent 不改變分類

- **WHEN** 某能力會在本機起一個外部 agent(如 `code/review-cross-model` 經 agent 多工器派工)
- **THEN** 判準 SHALL 仍為該能力自身效果的可逆性與外部可見性 —— 被起用的 agent 若受唯讀邊界約束,SHALL NOT 因「啟動了另一個程序」而改判為需鎖
