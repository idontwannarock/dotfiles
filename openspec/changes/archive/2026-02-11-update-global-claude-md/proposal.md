## Why

全域 CLAUDE.md 目前只有簡短的觸發規則，缺乏完整的工作流程說明。使用者和 Claude 都無法清楚知道確認步驟、流程規模選擇、以及各 superpowers 技能的觸發時機。

## What Changes

- 將全域 CLAUDE.md 改寫為中文，加入三步確認流程（確認使用→確認規模→確認推進模式）
- 加入小型/大型核心流程說明
- 加入可選擴充技能對照表，說明各 superpowers 的自動觸發時機

## Capabilities

### New Capabilities
- `workflow-instructions`: 全域 CLAUDE.md 的完整工作流程指令，涵蓋三步確認、核心流程、可選擴充

### Modified Capabilities

（無既有 spec 需修改）

## Impact

- 修改檔案：`claude/CLAUDE.md`（dotfiles 專案中的全域指令源檔）
- 同步影響：透過安裝腳本複製到 `~/.claude/CLAUDE.md`，影響所有專案的 Claude Code 行為
- 無程式碼變更，純文件更新
