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
