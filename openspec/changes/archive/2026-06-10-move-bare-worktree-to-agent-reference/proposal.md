## Why

`bare-worktree-workflow.md` 這份 reference 目前由 `.chezmoitemplates/bare-worktree-workflow.md` 一份 fragment，經 `dot_claude/` 與 `dot_codex/` 兩支 `.tmpl` **各自渲染一份副本**到 `~/.claude/` 與 `~/.codex/`。問題有二：

1. **內容重複** —— 同一份知識在兩個 tool 的家目錄各放一份，未來新增 AI tool 又要再加一支 `.tmpl`。
2. **散在 `~/.claude/` 根目錄** —— 該位置主要是 Claude 官方檔案（`settings.json`、`history.jsonl`、`.credentials.json` 等）的家，自訂 reference 檔放這裡有與官方未來新增檔案撞名的風險。

同時這份文件隨時間長到 157 行、相關主題被打散（建立 layout 的方法散兩處、Claude 狀態相關散三處），按需載入的粒度過粗。

## What Changes

- 新增 tool-agnostic 的 `~/.agent/reference/` 位置，作為跨 AI tool 共用 reference 的單一真相來源。
- 將 bare-worktree reference 從單一 157 行檔，**拆成 4 份**置於 `~/.agent/reference/bare-worktree/`：`index.md`（路由）、`operating.md`、`setup.md`（皆 tool-agnostic）、`claude-state.md`（Claude 專屬）。
- 收斂兩份 per-tool 副本：刪除 `dot_claude/` 與 `dot_codex/` 的 `bare-worktree-workflow.md.tmpl`，以及 `.chezmoitemplates/bare-worktree-workflow.md` fragment。
- 共用 fragment `user-system-prompt.md` 的 §7 指標（同時被 `~/.claude/CLAUDE.md` 與 `~/.codex/AGENTS.md` 渲染）改為絕對路徑 `~/.agent/reference/bare-worktree/index.md`，一處修改、兩 tool 同時生效。
- 更新 `dev-workflow` skill 中兩處硬指 `~/.claude/bare-worktree-workflow.md` 的連結。
- 清理 `~/.claude/` 下兩個已棄用的 machine-local 孤兒檔（`reference.md`、`worklog-config.md`）。

## Capabilities

### New Capabilities

- `agent-reference-layout`: 跨 AI tool 共用的 reference 文件配置 —— 中立的 `~/.agent/reference/` 位置、bare-worktree reference 的多檔拆分、以及各 tool 的 top-level prompt 如何以絕對路徑指向它。

### Modified Capabilities

（無既有 spec 需修改；現行 specs 未涵蓋 bare-worktree reference 或 user-system-prompt §7。）

## Impact

- **新增檔案**：`dot_agent/reference/bare-worktree/{index,operating,setup,claude-state}.md`（純靜態 `.md`，無 template 指令）→ 部署為 `~/.agent/reference/bare-worktree/*.md`。
- **刪除檔案**：`dot_claude/bare-worktree-workflow.md.tmpl`、`dot_codex/bare-worktree-workflow.md.tmpl`、`.chezmoitemplates/bare-worktree-workflow.md`。chezmoi apply 將移除對應的 `~/.claude/bare-worktree-workflow.md` 與 `~/.codex/bare-worktree-workflow.md`。
- **修改檔案**：`.chezmoitemplates/user-system-prompt.md`（§7 指標）、`dot_claude/skills/dev-workflow/SKILL.md`（L33、L44 連結）。
- **machine-local 清理**：`rm ~/.claude/reference.md`、`rm ~/.claude/worklog-config.md`（非 chezmoi 管，source 無涉）。
- 純文件變更，跨平台（Windows/macOS/Linux）行為一致，無程式碼變更。
