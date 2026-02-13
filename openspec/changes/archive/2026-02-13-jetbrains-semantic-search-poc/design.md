## Context

Claude Code 在 JetBrains IDE 中以 CLI 運行於內嵌 terminal，搜尋程式碼只能靠 grep/Glob。在大型 Java/Kotlin 專案中，grep 會撈出大量噪音（import、註解、同名不同 class），浪費 token 並導致 hallucination。

前期研究（`jetbrains-mcp-ide-actions` change）已調查完整的 MCP 生態：
- **官方 MCP Server（2025.2+）**：27 個工具，含 `get_symbol_info`、`search_in_files_by_text/regex`、`get_file_problems`
- **社群 IDE Index MCP Server plugin**（`jetbrains-index-mcp-plugin`，需 2025.1+）：提供 `ide_find_references`、`ide_call_hierarchy`、`ide_find_definition`、`ide_find_implementations`、`ide_find_symbol`、`ide_type_hierarchy`、`ide_find_super_methods`

使用者環境：IntelliJ IDEA >= 2025.2 + PyCharm，開發 Java/Kotlin 後端及 Python 專案。

## Goals / Non-Goals

**Goals:**
- 驗證官方 MCP Server + 社群 index plugin 在 Claude Code 中的可用性
- 透過對比實驗量化 semantic search vs grep 的 token 節省與正確性差異
- 設計搜尋決策樹工作流，讓 Claude Code 優先用 semantic search
- 產出可直接複製到 JetBrains 專案的 CLAUDE.md 搜尋策略範本

**Non-Goals:**
- 不做重構操作（Extract/Inline/Move/Change Signature）的整合
- 不自建 MCP plugin
- 不修改全域 CLAUDE.md

## Decisions

### 使用官方 MCP + 社群 index plugin（方案 B）

**選擇**：同時安裝官方 MCP Server 和社群 jetbrains-index-mcp-plugin，兩者互補。

**理由**：
- 官方提供 `get_symbol_info`（型別/文件）+ `get_file_problems`（inspection），但缺少 Find Usages 和 Call Hierarchy
- 社群 plugin 補上 Find Usages、Call Hierarchy、Go to Definition/Implementation
- 零開發成本，立即可用

**不選的替代方案**：
- 方案 A（官方 only）：缺少核心的 Find Usages 和 Call Hierarchy
- 方案 C（自建 MCP wrapper）：現有工具已覆蓋需求，不必造輪子

### POC 分兩階段

**Phase 1：工具可用性驗證**
在一個實際 Java 專案中逐一測試關鍵 MCP tool：
1. `get_symbol_info`（官方）— 符號宣告、型別、Javadoc
2. `ide_find_references`（社群）— Find Usages，精確列出引用點
3. `ide_call_hierarchy`（社群）— caller/callee chain
4. `ide_find_definition`（社群）— Go to Definition
5. `ide_find_implementations`（社群）— interface 的所有實作
6. `ide_find_symbol`（社群）— 模糊符號搜尋

每個測試記錄：回傳格式、延遲、精確度、token 消耗。

**Phase 2：對比實驗**
選一個實際修改任務（如重命名被廣泛引用的 service method），分兩組執行：
- A 組：純 grep + Read（現有方式）
- B 組：semantic search + call hierarchy

記錄 tool call 次數、總 token、結果正確性。

### 搜尋策略以 CLAUDE.md 範本落地

**選擇**：產出一段 CLAUDE.md 範本文字，使用者自行加到各 JetBrains 專案。

**理由**：
- 搜尋策略只在有 MCP Server 的環境才有意義
- 不同專案可能有不同需求（純 Java vs 混合語言）
- 保持全域 CLAUDE.md 乾淨

**搜尋決策樹核心邏輯**：
- 知道 class/method 名 → `get_symbol_info` → `ide_find_references` / `ide_call_hierarchy`
- 模糊名稱 → `ide_find_symbol` → 定位後走上面的路
- 非程式碼搜尋 → grep/Glob
- MCP 不可用 → grep fallback

## Risks / Trade-offs

- **[社群 plugin 穩定性]** → Phase 1 測試時評估，不穩定則回退到官方 only
- **[MCP 通訊延遲]** → 相比 token 節省，可忽略。但若高頻操作有感，記錄在 POC 結果中
- **[Claude Code MCP client 相容性]** → 社群 plugin 支援 SSE + Streamable HTTP，Claude Code 連接指令已有文件：`claude mcp add --transport http intellij-index http://127.0.0.1:29170/index-mcp/sse --scope user`，需實測確認
- **[CLAUDE.md 指引可能被忽略]** → 模型不一定每次都遵循搜尋決策樹。如果實驗顯示遵循率低，可能需要更強的指令或 hook 機制
