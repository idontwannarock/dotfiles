## Why

Claude Code 在 JetBrains IDE 中以 CLI 運行，搜尋程式碼只能靠 grep/Glob 純文字比對。在大型 Java/Kotlin 專案中，這導致大量 token 浪費（讀取不相關的 import、註解、同名但不同 class 的匹配）以及後續的 hallucination（噪音過多使模型編造不存在的關聯）。JetBrains 2025.2+ 已內建 MCP Server，社群 index plugin 提供 Find Usages 和 Call Hierarchy，現在可以用 semantic search 取代大部分 grep 操作。

## What Changes

- 安裝並驗證官方 MCP Server + 社群 jetbrains-index-mcp-plugin 在 Claude Code 中的可用性
- 執行對比實驗：semantic search vs grep，量測 token 節省與正確性差異
- 設計搜尋決策樹工作流（semantic search 優先、grep 降為 fallback）
- 產出 JetBrains 專案 CLAUDE.md 搜尋策略範本

## Capabilities

### New Capabilities
- `jetbrains-semantic-search`: JetBrains MCP semantic search POC 的驗證結果、對比實驗數據、搜尋決策樹工作流、CLAUDE.md 範本

### Modified Capabilities

_(無既有 spec 需修改)_

## Impact

- 新增文件：POC 驗證結果、CLAUDE.md 搜尋策略範本
- 不修改現有 dotfiles 設定或全域 CLAUDE.md
- 範本供未來各 JetBrains 專案個別採用
