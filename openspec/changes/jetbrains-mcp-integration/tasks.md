## 1. 環境設定

- [ ] 1.1 確認 IntelliJ IDEA 版本 >= 2025.2，啟用內建 MCP Server（Settings → Tools → MCP Server）
- [ ] 1.2 使用 Auto-Configure 設定 Claude Code 連接 MCP Server
- [ ] 1.3 安裝 jetbrains-index-mcp-plugin，確認 SSE/HTTP 端點可連
- [ ] 1.4 在 Claude Code 中執行 `mcp` 指令，確認兩個 MCP source 的工具都有列出

## 2. 工具可用性驗證

- [ ] 2.1 測試 `get_symbol_info`（官方）：指定一個 Java class/method，確認回傳宣告位置、型別、Javadoc
- [ ] 2.2 測試 `ide_find_references`（社群）：指定一個被多處引用的 method，確認精確列出所有引用點
- [ ] 2.3 測試 `ide_call_hierarchy`（社群）：指定一個 method，確認回傳 caller chain 和 callee chain
- [ ] 2.4 測試 `ide_find_definition`（社群）：指定一個符號引用，確認回傳宣告位置和完整 signature
- [ ] 2.5 測試 `ide_find_implementations`（社群）：指定一個 interface method，確認列出所有實作
- [ ] 2.6 測試 `rename_refactoring`（官方）：在 Java 專案中重命名一個被多處引用的 class/method，驗證所有引用更新
- [ ] 2.7 測試 `get_file_problems`（官方）：確認能取得 IntelliJ inspection 的錯誤與警告
- [ ] 2.8 測試 `execute_run_configuration`（官方）：確認能從 Claude Code 觸發測試執行
- [ ] 2.9 記錄每個工具的回傳格式、延遲、精確度

## 3. 對比實驗：semantic search vs grep

- [ ] 3.1 選定一個實際搜尋任務（如：找出某個被廣泛引用的 service method 的所有呼叫者）
- [ ] 3.2 A 組執行：用純 grep + Read 完成任務，記錄 tool call 次數和 token 消耗
- [ ] 3.3 B 組執行：用 semantic search + call hierarchy 完成同一任務，記錄 tool call 次數和 token 消耗
- [ ] 3.4 比對兩組結果的精確度（正確結果 / 總回傳結果）
- [ ] 3.5 整理對比實驗結果，寫入 POC 報告

## 4. 搜尋策略範本

- [x] 4.1 撰寫搜尋決策樹（symbol search → Find Usages / Call Hierarchy → grep fallback）
- [x] 4.2 撰寫 CLAUDE.md 搜尋策略範本，包含決策樹和使用說明
- [ ] 4.3 在一個測試專案中貼入範本，驗證 Claude Code 能根據指引優先使用 semantic search

## 5. 重構缺口評估（Phase 2 — 使用 1-2 週後）

- [ ] 5.1 記錄遇到「需要 Extract Method/Variable 但無法透過 MCP 執行」的場景次數與 token 消耗
- [ ] 5.2 記錄需要 Inline/Move/Change Signature 的場景，評估 Claude Code 直接編輯檔案的正確性
- [ ] 5.3 彙整評估結果，決定是否開獨立 change 自建 plugin
