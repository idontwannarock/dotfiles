# Codex CLI 設定

這個 repo 也會管理 Codex CLI 的基礎設定，目標不是硬把 Claude Code 的概念照搬，而是用 Codex 原生能力達成接近的操作體驗。

> 本文件記載 Codex 端的設定內容與操作方式。跨 change 反覆適用的判斷依據(為什麼這樣設計)在 [`context/`](../context/index.md);可驗收的行為契約在 `openspec/specs/`。

## 設定位置

| 項目 | 部署目標 | 說明 |
|------|----------|------|
| Global config | `~/.codex/config.toml` | 預設 model/effort、profiles、project doc fallback、輕量指令 |
| Project config | repo `.codex/config.toml` | 此 repo 的專案層級覆寫 |
| Personal skill | `~/.codex/skills/codex-claude-parity/SKILL.md` | 將 Claude workflow 轉成 Codex 的 skill |
| Project instructions | repo `AGENTS.md` | 專案層級記憶與工作規則 |

## 這套配置做了什麼

預設使用 `gpt-5.6-sol`，reasoning effort 為 `high`。這個 dotfiles repo 透過
`.codex/config.toml` 將 effort 覆寫為 `medium`；project config 只會在信任此 repo
時載入。

### 1. 保留 Codex 原生行為

不使用 `model_instructions_file` 覆蓋內建 prompt，而是用較輕量的 `instructions`、`AGENTS.md` 與 skill 疊加行為。這樣比較穩，也比較符合 Codex 官方建議。

### 2. 對齊 Claude 的工作節奏

`codex-claude-parity` skill 會引導 Codex 在非瑣碎任務時先做三件事：

1. 決定要不要走結構化流程
2. 判斷是小型還是大型任務
3. 決定逐步確認還是自動推進

這對應你現在 `~/.claude/CLAUDE.md` 裡的做法，但改用 Codex 的語彙與能力表達。

Claude 端是 command 的能力（`/handoff`、`/pickup`、`/arch-review`）在 Codex 一律包成 skill，部署到 `~/.codex/skills/<name>/`，與 Claude 共用 `.chezmoitemplates/skills/<name>.md` 的同一份 body —— 行為相同，只有 frontmatter 依各工具慣例不同。

其中 `arch-review` 的檔案方位與實跑經驗見 [claude-code.md](claude-code.md) 的 Arch Review 章節，行為契約見 [`openspec/specs/arch-review/spec.md`](../openspec/specs/arch-review/spec.md)。

八支 `review-*` skill 同樣共用 body。它們的觀點放在 `~/.agent/reference/review-lenses/` —— tool-agnostic 的純檔案，兩端指向同一批路徑。這對 Codex 特別重要：Codex 沒有 agent 機制，改制前拿到的是一張列著 `subagent_type` 名字的表，那些 agent 只存在於 Claude 端，Codex 實際能讀到的只有表格裡那一行 focus 說明。派工方式是 body 裡少數的 reader-axis 分支之一：Claude 平行派 subagent，Codex 逐個 lens 依序做完再開下一個。細節見 [claude-code.md](claude-code.md) 的 Code Review 章節。

唯一的例外是 `herdr`：它從上游同步而非自家撰寫，也不走 chezmoi 的檔案管理——
`run_onchange_install-herdr-skill.sh.tmpl` 依本機 herdr 版本抓對應 tag 的 SKILL.md，
同一份內容同時寫進 Claude 與 Codex 的 skill 目錄。該腳本寫入前會驗 description 有加
引號，因為 Codex 的 YAML frontmatter parser 比 Claude 嚴格；驗不過就保留舊檔並警告。
細節見 [claude-code.md](claude-code.md) 的「外部 skill：herdr」。

### 3. 讓 Codex 能讀既有專案慣例

`config.toml` 設定了：

- `project_doc_fallback_filenames = ["CLAUDE.md"]`

也就是說，若專案沒有 `AGENTS.md`，但有 root `CLAUDE.md`，Codex 仍可把它當成 project doc。對已經有 Claude 傳統的 repo 比較友善。

### 4. 提供常用 profile

- `quick`：快速處理瑣碎任務
- `deep`：較高推理深度，適合實作或重構
- `research`：研究/查證模式，啟用 live web search

### 5. 固定 TUI 顯示偏好

`config.toml` 設定 `tui.alternate_screen = "never"`，讓 Codex CLI 避免使用 terminal alternate screen。這比較接近 Windows Terminal / PowerShell 7 的 native scrollback 模式，可降低 full-screen redraw 後舊內容消失或黑屏的機率。

`tui.status_line` 同步目前選好的 footer 欄位：

```toml
["model-with-reasoning", "current-dir", "git-branch", "context-used", "five-hour-limit", "thread-title"]
```

### 6. Slack MCP server

Slack 直接列在同步的 MCP servers 中（見 `dot_codex/modify_config.toml` 與其
Windows 對應 `run_after_modify-codex-config.ps1.tmpl`）：

```toml
[mcp_servers.slack]
url = "https://mcp.slack.com/mcp"
```

server 條目由 chezmoi 隨 config 一併維護；Slack OAuth 登入請自行進入 Codex CLI
完成，屬每台機器各自的互動式設定，不會同步進 dotfiles。

## 使用方式

```bash
# 預設設定
codex

# 快速模式
codex -p quick

# 深度模式
codex -p deep

# 研究模式
codex -p research
```

## 與 Claude Code 的差異

以下能力不建議直接一比一照搬：

- Claude slash commands：改用 Codex skills / review mode / subagents
- Claude plugins：依能力改用 Codex 原生 plugins 或 MCP，不直接搬用 Claude plugin 設定
- Claude 全域 prompt 覆寫：改用 `instructions` + `AGENTS.md` + skills

這樣的好處是比較貼近 Codex 官方設計，也比較不容易在版本升級後失效。
