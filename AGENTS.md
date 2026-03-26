# Codex 專案指引

## 專案性質

這個 repo 是 dotfiles 的 source of truth，不是目前電腦上已生效的最終設定檔集合。

## 變更流程

1. 先在目前電腦的實際環境測試設定是否可用。
2. 確認生效後，再把對應變更同步回這個 repo。
3. 優先維持跨平台一致性，至少考慮 Windows、macOS、Linux/WSL。
4. 行為有改變時，更新對應文件。

## 本 repo 的相關位置

- `dot_claude/`：由 chezmoi 管理並部署到 `~/.claude/`
- `docs/claude-code.md`：Claude Code 設定與 workflow 說明
- `.claude/CLAUDE.md`：這個 repo 原本的 Claude 專案記憶
- `dot_codex/`：由 chezmoi 管理並部署到 `~/.codex/`

## Codex 對齊原則

當任務與 Claude/Codex 體驗對齊有關時：

- 優先沿用這個 repo 既有 workflow，而不是發明第二套平行規則。
- Codex 原生能力優先：`AGENTS.md`、skills、profiles、MCP、subagents。
- 不要依賴 `model_instructions_file` 覆蓋內建 prompt；那只適合非常特殊的情況。
- 如果需要對齊 Claude 的 `/git:*`、`/code:*`、OpenSpec 或 worklog 流程，優先參考 `dot_claude/CLAUDE.md` 與 `docs/claude-code.md`，再用 Codex 的 skills/subagents 重新表達。
