## ADDED Requirements

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
