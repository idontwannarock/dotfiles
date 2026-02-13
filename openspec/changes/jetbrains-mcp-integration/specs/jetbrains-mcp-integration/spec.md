## ADDED Requirements

### Requirement: Research document covers existing MCP solutions
研究文件 SHALL 記錄所有已知的 JetBrains MCP 方案，包含官方與社群方案的工具清單與能力範圍。

#### Scenario: Official MCP Server documented
- **WHEN** 查看研究文件
- **THEN** 包含 JetBrains 2025.2+ 內建 MCP Server 的完整工具清單（27 個工具）、設定方式、文件連結

#### Scenario: Community index plugin documented
- **WHEN** 查看研究文件
- **THEN** 包含 jetbrains-index-mcp-plugin 的能力清單、GitHub 連結、通訊方式

#### Scenario: Community refactoring plugin documented
- **WHEN** 查看研究文件
- **THEN** 包含 jetbrains-plugin-mcp-refactoring 的現狀評估（WIP/可用/成熟）

### Requirement: Gap analysis identifies missing IDE actions
缺口分析 SHALL 明確標示每個目標 IDE 動作的可用狀態（已有/需社群 plugin/缺口）。

#### Scenario: Refactoring actions assessed
- **WHEN** 查看缺口分析
- **THEN** 包含 Rename、Extract Method/Variable、Inline、Move、Change Signature 的可用狀態

#### Scenario: Navigation actions assessed
- **WHEN** 查看缺口分析
- **THEN** 包含 Find Usages、Go to Definition/Implementation、Type/Call Hierarchy 的可用狀態

### Requirement: MCP tool availability verified
POC SHALL 驗證官方 MCP Server 和社群 index plugin 的每個目標工具在 Claude Code 中可正常呼叫並回傳有用結果。

#### Scenario: Symbol info retrieval
- **WHEN** Claude Code 透過官方 MCP 呼叫 `get_symbol_info`，指定一個已知的 Java class 或 method
- **THEN** 回傳包含宣告位置、型別資訊、Javadoc 的結構化結果

#### Scenario: Find Usages via reference discovery
- **WHEN** Claude Code 透過社群 plugin 呼叫 reference discovery，指定一個被多處引用的 method
- **THEN** 回傳該 method 的所有引用點列表，不含同名但不同 class 的誤匹配

#### Scenario: Call hierarchy retrieval
- **WHEN** Claude Code 透過社群 plugin 呼叫 call hierarchy，指定一個 method
- **THEN** 回傳該 method 的 caller chain 和 callee chain

#### Scenario: Go to Definition
- **WHEN** Claude Code 透過社群 plugin 呼叫 definition navigation，指定一個符號引用
- **THEN** 回傳該符號的宣告位置和完整 signature

#### Scenario: Go to Implementation
- **WHEN** Claude Code 透過社群 plugin 呼叫 implementation discovery，指定一個 interface method
- **THEN** 回傳所有實作該 method 的 class 和位置

### Requirement: Comparison experiment quantifies improvement
POC SHALL 執行對比實驗，量化 semantic search 相對於 grep 的改善幅度。

#### Scenario: Token consumption comparison
- **WHEN** 同一個程式碼搜尋任務分別用 grep 和 semantic search 完成
- **THEN** 記錄兩組的 tool call 次數和估計 token 消耗，semantic search 組 SHALL 顯著減少

#### Scenario: Accuracy comparison
- **WHEN** 同一個搜尋任務的結果以人工判斷為準
- **THEN** semantic search 組的精確度（正確結果 / 總回傳結果）SHALL 高於 grep 組

### Requirement: Search strategy template produced
POC SHALL 產出一份 CLAUDE.md 搜尋策略範本，可直接複製到 JetBrains 專案中使用。

#### Scenario: Template contains decision tree
- **WHEN** 查看搜尋策略範本
- **THEN** 包含完整的搜尋決策樹：symbol search → Find Usages / Call Hierarchy → grep fallback

#### Scenario: Template is self-contained
- **WHEN** 將範本貼入一個新 JetBrains 專案的 CLAUDE.md
- **THEN** Claude Code 能根據範本指引，在有 MCP Server 可用時自動優先使用 semantic search

### Requirement: Action plan defines phased approach
行動方案 SHALL 定義分階段策略，從零開發成本的現有方案開始，逐步評估是否需要自建 plugin。

#### Scenario: Phase 1 uses existing solutions
- **WHEN** 查看 Phase 1 行動方案
- **THEN** 描述如何啟用官方 MCP Server 並安裝社群 index plugin，不涉及自建開發

#### Scenario: Phase 2 evaluates gap impact
- **WHEN** 查看 Phase 2 行動方案
- **THEN** 描述如何在實際使用中評估 Extract/Inline/Move/Change Signature 缺口的影響程度

#### Scenario: Phase 3 plans custom plugin if needed
- **WHEN** 查看 Phase 3 行動方案
- **THEN** 描述基於 JetBrains MCP extension point 開發 plugin 的技術路線
