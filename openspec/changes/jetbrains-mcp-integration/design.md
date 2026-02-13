## Context

Claude Code 在 JetBrains IDE 中以 CLI 運行於內嵌 terminal，透過 stdin/stdout 通訊，對 IDE 是黑箱。JetBrains 從 2025.2 開始內建 MCP Server，作為 IDE 與外部 AI 工具之間的橋樑。社群也有增強 plugin 提供更深入的語意分析。

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
- 啟用並驗證官方 MCP Server + 社群 index plugin 的所有工具
- 透過對比實驗量化 semantic search vs grep 的改善
- 評估重構缺口的實際影響
- 產出可複製的 CLAUDE.md 搜尋策略範本

**Non-Goals:**
- 不在本 change 開發自建 plugin（屬於後續 change）
- 不修改全域 CLAUDE.md

## Decisions

### 同時使用官方 MCP + 社群 index plugin

**理由**：官方提供 `get_symbol_info` + `get_file_problems`，但缺 Find Usages 和 Call Hierarchy；社群 plugin 補上這些核心導航能力。零開發成本，立即可用。

### 分階段推進

**Phase 1：環境設定 + 工具驗證**
啟用 MCP Server、安裝 index plugin、逐一測試每個工具的回傳格式和精確度。

**Phase 2：對比實驗**
同一搜尋任務用 grep vs semantic search，量化 token 和正確性差異。

**Phase 3：重構缺口評估**
實際使用一段時間後，評估 Extract/Inline/Move/Change Signature 缺口的影響。如確認有影響，開獨立 change 自建 plugin。

### 搜尋策略以 CLAUDE.md 範本落地

產出範本文字供各 JetBrains 專案個別採用，保持全域 CLAUDE.md 乾淨。

**搜尋決策樹核心邏輯**：
- 知道 class/method 名 → `get_symbol_info` → `ide_find_references` / `ide_call_hierarchy`
- 模糊名稱 → `ide_find_symbol` → 定位後走精確路
- 非程式碼搜尋 → grep/Glob
- MCP 不可用 → grep fallback

## Risks / Trade-offs

- **[社群 plugin 穩定性未知]** → Phase 1 先試用，不穩定可回退到僅用官方 MCP
- **[官方 MCP 工具可能持續擴充]** → JetBrains 可能在後續版本補上 Find Usages、Extract 等，自建 plugin 可能變多餘
- **[MCP 通訊延遲]** → 相比 token 節省可忽略，但記錄在 POC 結果中
- **[Claude Code MCP client 相容性]** → 社群 plugin 支援 SSE + Streamable HTTP，需實測確認
- **[CLAUDE.md 指引可能被忽略]** → 模型不一定每次遵循搜尋決策樹，如遵循率低可能需更強的 hook 機制
