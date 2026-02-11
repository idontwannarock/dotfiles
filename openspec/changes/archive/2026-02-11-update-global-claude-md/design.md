## Context

全域 CLAUDE.md（`claude/CLAUDE.md`）是 dotfiles 專案管理的設定檔，透過安裝腳本複製到 `~/.claude/CLAUDE.md`，控制所有專案中 Claude Code 的預設行為。目前內容僅有簡短的英文觸發規則，缺乏完整流程說明。

## Goals / Non-Goals

**Goals:**
- 將全域 CLAUDE.md 改寫為中文，加入三步確認流程與完整工作流程說明
- 內容在 dotfiles 專案中維護，透過既有安裝腳本同步到其他電腦

**Non-Goals:**
- 不修改專案層級的 `.claude/CLAUDE.md`
- 不修改安裝腳本（已有 `cp claude/CLAUDE.md ~/.claude/CLAUDE.md` 邏輯）
- 不新增程式碼或 skill

## Decisions

1. **語言選擇：中文** — 與專案其他文件（README、專案 CLAUDE.md）保持一致，使用者母語閱讀更順暢
2. **結構：核心流程 + 可選擴充** — 核心流程保持簡潔（三步確認 + 兩條路線），可選擴充以表格列出各 superpowers 觸發時機，避免流程過長
3. **只修改源檔** — 修改 `claude/CLAUDE.md`（專案中的源檔），不直接改 `~/.claude/CLAUDE.md`（部署目標），符合 dotfiles 的管理原則

## Risks / Trade-offs

- [全域指令過長導致 context 浪費] → 保持精簡，可選擴充用表格壓縮篇幅
- [同步到其他電腦需重跑安裝腳本] → 這是 dotfiles 專案既有的設計，無需額外處理
