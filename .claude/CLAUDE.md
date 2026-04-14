# Claude Code 專案指令

## 專案說明

跨平台個人設定檔管理專案，透過 [chezmoi](https://www.chezmoi.io/) 同步到 Windows、macOS、Linux/WSL。
此 repo 是 source of truth，**不是**直接生效在當前電腦上的設定。

## 變更設定檔的工作流程

1. **先在當前電腦測試**：變更當前電腦的實際設定，確認功能正常運作
2. **確認生效後再更新專案**：確認沒問題後，才將變更同步到此專案的相關同步設定檔
3. **考慮平台通用性**：盡量讓設定能跨平台使用（Windows、macOS、Linux）
4. **更新文件**：將變更記錄在 README 或 `docs/` 下的對應文件中
