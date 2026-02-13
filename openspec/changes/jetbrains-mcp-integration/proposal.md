## Why

Claude Code 在 JetBrains IDE 中以 CLI 運行，對 IDE 是黑箱：

1. **搜尋低效**：只能靠 grep/Glob 純文字比對，大型 Java/Kotlin 專案會撈出大量噪音（import、註解、同名不同 class），浪費 token 並導致 hallucination
2. **重構粗糙**：無法呼叫 IDE 的 Rename、Extract Method 等語意感知重構，只能靠文字替換（正確性不足）

JetBrains 2025.2+ 已內建 MCP Server（27 個工具），社群也有 index plugin 提供 Find Usages、Call Hierarchy 等深層導航。可以透過 MCP 橋接 Claude Code 與 IDE 能力。

## What Changes

- 啟用官方 MCP Server + 社群 jetbrains-index-mcp-plugin，驗證工具可用性
- 執行對比實驗：semantic search vs grep，量測 token 節省與正確性差異
- 評估重構操作缺口（Extract/Inline/Move/Change Signature）的實際影響
- 設計搜尋決策樹工作流，產出 JetBrains 專案 CLAUDE.md 搜尋策略範本

## Capabilities

### New Capabilities
- `jetbrains-mcp-integration`: JetBrains MCP 生態調查、缺口分析、POC 驗證結果、搜尋策略範本

### Modified Capabilities

_(無既有 spec 需修改)_

## Impact

- 新增文件：POC 驗證結果、CLAUDE.md 搜尋策略範本
- 不修改現有 dotfiles 設定或全域 CLAUDE.md
- 後續可能涉及：自建 plugin 補缺口（獨立 change）
