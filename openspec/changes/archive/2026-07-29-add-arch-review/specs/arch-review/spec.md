## ADDED Requirements

### Requirement: 跨工具部署與手動觸發

`arch-review` SHALL 以 chezmoi shared-body(`home/.chezmoitemplates/skills/arch-review.md`)搭配 per-tool wrapper 部署:Claude 端為 command(`home/dot_claude/commands/arch-review.md.tmpl`)且 SHALL 標記 `disable-model-invocation: true`;Codex 端為 skill(`home/dot_codex/skills/arch-review/SKILL.md.tmpl`)。兩端 SHALL 共用同一份 body,行為 SHALL NOT 分叉。

#### Scenario: chezmoi apply 後雙工具可用
- **WHEN** `chezmoi apply` 完成
- **THEN** `~/.claude/commands/arch-review.md` 與 `~/.codex/skills/arch-review/SKILL.md` SHALL 存在,且由同一份 shared body 渲染

#### Scenario: 模型不得自行呼叫
- **WHEN** 使用者未輸入 `/arch-review`
- **THEN** Claude SHALL NOT 自行啟動架構體檢(由 `disable-model-invocation: true` 保證)

#### Scenario: Codex frontmatter 為嚴格 YAML
- **WHEN** 以 YAML parser 解析 `~/.codex/skills/arch-review/SKILL.md` 的 frontmatter
- **THEN** SHALL 解析成功(description 若含 `:` SHALL 加引號)

### Requirement: 兩階段掃描紀律

`arch-review` SHALL 分兩階段掃描:階段一為不讀檔案內容的廉價全庫盤點(目錄樹、檔案規模分布、依賴方向、名稱重複訊號);階段二 SHALL 依階段一結果選出 3-5 個可疑區才讀取內容深挖。深挖區數量 SHALL NOT 超過 5 個。`arch-review` SHALL 接受可選的 path 參數以縮限掃描範圍。

#### Scenario: 預設全庫兩階段
- **WHEN** 使用者輸入 `/arch-review` 且未帶參數
- **THEN** SHALL 先產出全庫結構盤點,再據此選定至多 5 個深挖區

#### Scenario: 帶 path 參數縮限
- **WHEN** 使用者輸入 `/arch-review src/payment`
- **THEN** 兩階段掃描 SHALL 僅在該路徑範圍內進行

#### Scenario: 深挖區上限
- **WHEN** 階段一盤點出多於 5 個可疑區
- **THEN** SHALL 依可疑程度排序並僅深挖前 5 個,且 SHALL 於報告中說明有哪些區未深挖

### Requirement: 判準來源分層且降級可見

模組邊界的判準 SHALL 依可用資訊分層:存在 `openspec/project.md` 時 SHALL 以其詞彙表為權威判準;不存在時 SHALL 從 codebase 推斷 domain 語言(目錄結構、型別/類別名、導出介面)。使用推斷判準時,報告 SHALL 明示該判準為推斷而非權威。`arch-review` SHALL NOT 寫入 `openspec/project.md`。

#### Scenario: 有 project.md
- **WHEN** 執行體檢且 `openspec/project.md` 存在
- **THEN** SHALL 讀取其詞彙表作為模組邊界判準,並於報告標示判準來源為 `project.md`

#### Scenario: 無 project.md 時降級並標示
- **WHEN** 執行體檢且 `openspec/project.md` 不存在
- **THEN** SHALL 從 codebase 推斷 domain 語言,且報告 SHALL 明確標示判準為推斷而非權威

#### Scenario: 不寫入 project.md
- **WHEN** 體檢過程中發現疑似長青的 domain 詞彙
- **THEN** SHALL NOT 寫入 `openspec/project.md`(該檔僅於 sync/archive 階段寫入)

### Requirement: 產出為 pickup 相容文檔

`arch-review` SHALL 將結果寫入 `~/.agent/handoffs/<repo-slug>/<ID>.md`,其中 repo-slug 與 ID 沿用既有 handoff 約定(ID 形如 `YYYY-MM-DD-HHMM__arch-review`)。該文檔 SHALL 包含 `## Suggested skills` 與 `## Next steps` 兩段以相容 `pickup`。`arch-review` SHALL NOT 修改 `handoff` 或 `pickup` 的行為。

#### Scenario: 產出可被 pickup 接手
- **WHEN** 體檢完成寫出報告後,使用者於任一新 session 執行 `/pickup <ID>`
- **THEN** `pickup` SHALL 成功解析該檔,並依其 `## Suggested skills` 與 `## Next steps` 接續執行

#### Scenario: 報告路徑與 ID 約定
- **WHEN** 體檢完成
- **THEN** 報告 SHALL 位於 `~/.agent/handoffs/<repo-slug>/` 下,檔名 SHALL 為 `<YYYY-MM-DD-HHMM>__arch-review.md`,且 SHALL 向使用者印出絕對路徑與可複製的 `/pickup <ID>` 指令

#### Scenario: 不寫入工具專屬目錄
- **WHEN** 體檢完成寫檔
- **THEN** SHALL NOT 寫入任何工具專屬目錄(`.claude/`、`.codex/` 等)或 repo 內部

#### Scenario: 無建議 skill 時不得使用 bullet
- **WHEN** 體檢無候選、`## Suggested skills` 段無內容可列
- **THEN** SHALL 以非 bullet 的句子表達(如 `No skills needed -- this review produced no candidates.`),SHALL NOT 寫成 `- None` —— bullet 形式與真實 skill 條目無法區分,`pickup` 會嘗試呼叫它

#### Scenario: 不得列出會提前動工的 skill
- **WHEN** 撰寫 `## Suggested skills` 段
- **THEN** SHALL NOT 列出 `dev-workflow` 或其他會對候選動工的 skill —— `pickup` 會在讀 `## Next steps` 之前無確認地呼叫該段所有項目,等同在使用者選定候選前就啟動 change 生命週期

### Requirement: 只提候選不動手

`arch-review` SHALL 僅產出排序過的重構候選,每項 SHALL 包含問題陳述、證據(檔案路徑加具體事證)、影響範圍與建議動作。`arch-review` SHALL NOT 修改任何原始碼,亦 SHALL NOT 自動建立 OpenSpec change。

#### Scenario: 不修改程式碼
- **WHEN** 體檢識別出重構機會
- **THEN** SHALL 僅記入報告,SHALL NOT 編輯任何原始檔

#### Scenario: 候選附證據
- **WHEN** 報告列出一項重構候選
- **THEN** 該項 SHALL 包含至少一個具體檔案路徑作為證據,SHALL NOT 僅有抽象評斷

#### Scenario: 不自動開 change
- **WHEN** 體檢完成
- **THEN** SHALL NOT 自動建立 OpenSpec change;落地與否 SHALL 由使用者於 pickup 後決定

#### Scenario: codebase 健康時不湊候選
- **WHEN** 兩階段掃描後未發現值得處理的問題
- **THEN** SHALL 明確回報無候選並停止,SHALL NOT 為了產出而列出低價值項目
