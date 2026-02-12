## Context

Claude Code 在 JetBrains IDE 中以 CLI 運行於內嵌 terminal，透過 stdin/stdout 通訊，對 IDE 是黑箱。相比之下，IdeaVim 等原生 plugin 跑在 IDE 的 JVM 進程內，可透過 `ActionManager` 直接呼叫任意 IDE action。

JetBrains 從 2025.2 開始內建 MCP Server，作為 IDE 與外部 AI 工具之間的橋樑。社群也有增強 plugin 提供更深入的語意分析。

### 現有方案調查

#### 1. JetBrains 官方內建 MCP Server（2025.2+）

27 個工具，支援 Claude Code 自動設定（Settings → Tools → MCP Server → Auto-Configure）。

| 類別 | 工具 | 說明 |
|------|------|------|
| 重構 | `rename_refactoring` | 語意感知重命名，自動更新所有引用 |
| 重構 | `reformat_file` | 程式碼格式化 |
| 分析 | `get_symbol_info` | 符號宣告、文件、型別資訊 |
| 分析 | `get_file_problems` | IntelliJ inspection 錯誤和警告 |
| 搜尋 | `search_in_files_by_text` / `search_in_files_by_regex` | 全專案搜尋 |
| 搜尋 | `find_files_by_glob` / `find_files_by_name_keyword` | 檔案搜尋 |
| 檔案 | `get_file_text_by_path` / `replace_text_in_file` / `create_new_file` | 檔案操作 |
| 檔案 | `open_file_in_editor` / `list_directory_tree` / `get_all_open_file_paths` | 編輯器/目錄 |
| 專案 | `get_project_dependencies` / `get_project_modules` / `get_repositories` | 專案結構 |
| 執行 | `get_run_configurations` / `execute_run_configuration` | 執行 build/test |
| 終端 | `execute_terminal_command` | Shell 指令 |

文件：https://www.jetbrains.com/help/idea/mcp-server.html

#### 2. 社群 plugin：jetbrains-index-mcp-plugin

透過 IDE 的 AST 和索引提供跨專案引用解析，通訊方式為 SSE + Streamable HTTP。

| 類別 | 能力 | 說明 |
|------|------|------|
| 導航 | Symbol reference discovery | 類似 Find Usages |
| 導航 | Definition navigation | Go to Definition |
| 導航 | Type / Call hierarchy | 型別與呼叫階層 |
| 導航 | Implementation discovery | Go to Implementation |
| 導航 | Method override chain | 方法覆寫鏈 |
| 重構 | Safe rename | 語意安全重命名 |
| 重構 | Safe delete | 使用檢查後安全刪除（Java/Kotlin） |
| 分析 | Diagnostic analysis | 錯誤與警告 |
| 搜尋 | Symbol search | 模糊符號搜尋 |

GitHub：https://github.com/hechtcarmel/jetbrains-index-mcp-plugin

#### 3. 社群 WIP：jetbrains-plugin-mcp-refactoring

嘗試做更完整的重構 MCP server，但目前為早期空殼（2025-04 建立，README 仍是範本）。
連結：https://mcp.so/server/jetbrains-plugin-mcp-refactoring/Harineko0

### 缺口分析

| 能力 | 官方 MCP | 社群 index plugin | 狀態 |
|------|---------|-------------------|------|
| Rename | ✅ | ✅ | 已有 |
| Reformat | ✅ | — | 已有 |
| Find Usages | ❌ | ✅ | 需社群 plugin |
| Go to Definition | ❌ | ✅ | 需社群 plugin |
| Type / Call Hierarchy | ❌ | ✅ | 需社群 plugin |
| Go to Implementation | ❌ | ✅ | 需社群 plugin |
| Safe Delete | ❌ | ✅ | 需社群 plugin |
| Run tests / build | ✅ | — | 已有 |
| Extract Method/Variable | ❌ | ❌ | **缺口** |
| Inline | ❌ | ❌ | **缺口** |
| Move | ❌ | ❌ | **缺口** |
| Change Signature | ❌ | ❌ | **缺口** |

## Goals / Non-Goals

**Goals:**
- 記錄完整的 JetBrains MCP 生態調查結果
- 明確標示哪些能力已可使用、哪些仍有缺口
- 規劃分階段行動方案

**Non-Goals:**
- 本 change 不涉及實際 plugin 開發或 IDE 設定變更
- 不做 JetBrains plugin 的程式碼實作
- 不修改現有 Claude Code 設定

## Decisions

### 分階段策略

**Phase 1：用現有方案（官方 MCP + 社群 index plugin）**
先升級 IntelliJ 到 2025.2+，啟用內建 MCP Server 並 Auto-Configure Claude Code，再安裝 jetbrains-index-mcp-plugin。這已覆蓋 Rename、Find Usages、Type Hierarchy、Go to Implementation 等核心需求。

理由：零開發成本，立即可用，覆蓋大部分需求。

**Phase 2：評估缺口的實際影響**
實際使用一段時間後，評估 Extract Method/Variable、Inline、Move、Change Signature 的缺失是否造成顯著的 token 浪費或正確性問題。

理由：缺口可能在實務中影響不大（Claude Code 直接編輯可能足夠），避免過早投入開發。

**Phase 3（視需要）：自建 plugin 補缺口**
如 Phase 2 確認缺口有實際影響，基於 JetBrains MCP extension point 開發 plugin，暴露 Extract/Inline/Move/Change Signature 等 action。技術路線：JetBrains Plugin SDK → MCP tool extension → IDE 內部 refactoring API。

### 不選擇的替代方案

- **純 REST API bridge**：不選擇，因為官方已有 MCP 架構，沒必要另起爐灶
- **JetBrains Remote Development API**：不選擇，主要用於遠端開發場景，非本地 IDE action 操作

## Risks / Trade-offs

- **[社群 plugin 穩定性未知]** → Phase 1 先試用，如果不穩定可回退到僅用官方 MCP
- **[官方 MCP 工具可能持續擴充]** → JetBrains 可能在後續版本補上 Find Usages、Extract 等工具，自建 plugin 可能變得多餘。持續關注官方動態
- **[MCP 通訊開銷]** → MCP tool call 有額外的網路/序列化開銷，對高頻操作可能有延遲感。但相比 token 節省，這個開銷可忽略
- **[Claude Code MCP client 相容性]** → Claude Code 的 MCP client 實作可能有限制，需實測確認所有工具能正常運作
