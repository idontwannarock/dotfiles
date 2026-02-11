## ADDED Requirements

### Requirement: 三步確認流程
收到實作任務時，Claude SHALL 依序執行三步確認：確認是否使用 OpenSpec + Superpowers 流程、確認規模（小型/大型）、確認推進模式（逐步/自動），三步皆完成後才開始工作。

#### Scenario: 使用者選擇使用流程
- **WHEN** 使用者回答「是」要使用 OpenSpec + Superpowers 流程
- **THEN** Claude SHALL 進入第二步，根據任務複雜度建議規模並等待確認

#### Scenario: 使用者選擇不使用流程
- **WHEN** 使用者回答「否」
- **THEN** Claude SHALL 直接以標準方式進行，不再詢問規模和推進模式

#### Scenario: 瑣碎任務自動跳過
- **WHEN** 任務為改 typo、一行修改、簡單問答等瑣碎任務
- **THEN** Claude SHALL 跳過詢問，直接進行

### Requirement: 規模選擇
Claude SHALL 提供兩種規模選項，並根據任務複雜度給出建議。

#### Scenario: 小型流程
- **WHEN** 使用者確認走小型流程
- **THEN** Claude SHALL 使用 `opsx:ff` 一次產生所有 artifact 後直接實作

#### Scenario: 大型流程
- **WHEN** 使用者確認走大型流程
- **THEN** Claude SHALL 使用 `opsx:new` → `opsx:continue` 逐步產生 artifact

### Requirement: 推進模式選擇
Claude SHALL 提供兩種推進模式供使用者選擇。

#### Scenario: 逐步確認模式
- **WHEN** 使用者選擇逐步確認
- **THEN** Claude SHALL 在每個 skill 結束後等使用者說「繼續」再推進

#### Scenario: 自動推進模式
- **WHEN** 使用者選擇自動推進
- **THEN** Claude SHALL 做完一步直接下一步，只在關鍵點暫停

### Requirement: 核心流程定義
CLAUDE.md SHALL 包含小型與大型兩條核心流程路線的完整步驟。

#### Scenario: 小型核心流程
- **WHEN** 選擇小型流程
- **THEN** 執行順序 SHALL 為：ensure-openspec → brainstorming → opsx:ff → opsx:apply → opsx:verify → opsx:archive

#### Scenario: 大型核心流程
- **WHEN** 選擇大型流程
- **THEN** 執行順序 SHALL 為：ensure-openspec → brainstorming → opsx:new → opsx:continue（重複）→ writing-plans → opsx:apply → verification-before-completion → opsx:verify → opsx:archive

### Requirement: 可選擴充技能對照表
CLAUDE.md SHALL 包含可選 superpowers 技能的觸發時機對照表，這些技能由 Claude 視情況自動引入，不需使用者手動觸發。

#### Scenario: 表格包含所有可選技能
- **WHEN** 使用者查看可選擴充段落
- **THEN** SHALL 列出以下技能及其觸發時機：using-git-worktrees、subagent-driven-development、dispatching-parallel-agents、test-driven-development、systematic-debugging、requesting-code-review、receiving-code-review、finishing-a-development-branch

### Requirement: 文件語言為中文
全域 CLAUDE.md 的內容 SHALL 以中文撰寫。

#### Scenario: 語言一致性
- **WHEN** 安裝腳本將 CLAUDE.md 部署到 ~/.claude/
- **THEN** 使用者看到的全域指令 SHALL 為中文
