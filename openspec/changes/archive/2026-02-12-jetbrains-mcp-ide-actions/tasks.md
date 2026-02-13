## 1. Phase 1 — 啟用現有 MCP 方案

- [ ] 1.1 確認 IntelliJ IDEA 版本 >= 2025.2，啟用內建 MCP Server（Settings → Tools → MCP Server）
- [ ] 1.2 使用 Auto-Configure 設定 Claude Code 連接 MCP Server
- [ ] 1.3 安裝 jetbrains-index-mcp-plugin，確認 SSE/HTTP 端點可連
- [ ] 1.4 實測 `rename_refactoring` — 在 Java 專案中重命名一個被多處引用的 class/method，驗證所有引用更新
- [ ] 1.5 實測導航工具 — Find Usages、Go to Definition、Type Hierarchy，確認回傳結果正確
- [ ] 1.6 實測 `get_file_problems` — 確認能取得 IntelliJ inspection 的錯誤與警告
- [ ] 1.7 實測 `execute_run_configuration` — 確認能從 Claude Code 觸發測試執行

## 2. Phase 2 — 評估缺口影響

- [ ] 2.1 在實際開發中使用 1-2 週，記錄遇到「需要 Extract Method/Variable 但無法透過 MCP 執行」的場景次數與 token 消耗
- [ ] 2.2 記錄需要 Inline/Move/Change Signature 的場景，評估 Claude Code 直接編輯檔案的正確性
- [ ] 2.3 彙整評估結果，決定是否進入 Phase 3

## 3. Phase 3（條件觸發）— 自建 Plugin 補缺口

- [ ] 3.1 研究 JetBrains MCP extension point API，確認如何註冊自訂 MCP tool
- [ ] 3.2 建立 IntelliJ Plugin 專案，實作最小 POC：暴露 Extract Method 為 MCP tool
- [ ] 3.3 擴充 POC 至 Extract Variable、Inline、Move、Change Signature
- [ ] 3.4 發布至 JetBrains Marketplace 或作為本地 plugin 使用
