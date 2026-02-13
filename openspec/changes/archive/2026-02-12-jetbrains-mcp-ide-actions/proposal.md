## Why

Claude Code 在 JetBrains IDE 中以 CLI 運行，無法呼叫 IDE 的重構與導航功能。每次 Rename 需讀取所有相關檔案自行文字替換（浪費 token），且無法利用 Java 強型別 + IDE 語意理解的優勢（正確性不足）。JetBrains 2025.2+ 已內建 MCP Server，社群也有增強 plugin，但目前未在此專案設定使用。

## What Changes

- 研究並記錄 JetBrains MCP 生態現狀（官方內建 MCP Server、社群 index plugin、社群 refactoring plugin）
- 記錄缺口分析：哪些 IDE 動作已可透過 MCP 使用、哪些仍缺
- 規劃下一步行動方案：設定現有方案 + 評估自建 plugin 補缺口

## Capabilities

### New Capabilities
- `jetbrains-mcp-research`: JetBrains MCP IDE Actions 的研究結果、缺口分析與行動方案

### Modified Capabilities

_(無既有 spec 需修改)_

## Impact

- 新增文件：OpenSpec change artifacts（proposal、design、specs、tasks）
- 無程式碼變更
- 後續行動可能涉及：JetBrains IDE MCP Server 設定、社群 plugin 安裝、自建 plugin POC（均為獨立的後續 change）
