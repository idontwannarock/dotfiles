## Context

`bare-worktree-workflow.md` 是一份 progressive-disclosure reference：top-level prompt（`~/.claude/CLAUDE.md`、`~/.codex/AGENTS.md`）只放一段指標，本體僅在 cwd 命中 bare+worktree layout 時才被讀入。本體內容由 `.chezmoitemplates/bare-worktree-workflow.md` 一份 fragment 提供，經兩支 `.tmpl`（`dot_claude/`、`dot_codex/`）各渲染一份到對應 tool 的家目錄。

## Goals / Non-Goals

**Goals**
- 單一真相：bare-worktree reference 只存一份，跨 tool 共用。
- 中立位置：脫離 `~/.claude/` 根目錄，避免與 Claude 官方檔撞名。
- 更細的按需載入粒度：拆成多檔，依需求只載相關段落。

**Non-Goals**
- 不改 progressive-disclosure 機制本身（指標仍在 prompt、本體仍按需載）。
- 不把 `dev-workflow` 之類的 skill 改成 reference（skill 的觸發/可呼叫性是其價值，與本次無關）。
- 不主動為 AGENTS.md/GEMINI.md 新增「額外」指標 —— §7 為 Claude 與 Codex 共用，改一處即雙生效；未來 tool 的接線屬後續工作。

## Decisions

### 為什麼是 `~/.agent/reference/` 而非 per-tool 副本

現行兩份 `.tmpl` 副本是「每 tool 一份」的反模式：知識重複、擴充成本隨 tool 數線性增加。改放中立的 `~/.agent/`（repo 已有 `AGENTS.md`/`dot_codex/AGENTS.md.tmpl` 的 tool-agnostic 慣例為基礎），所有 tool 的 prompt 以絕對路徑指向同一份。指標 §7 位於共用 fragment `user-system-prompt.md`，故 Claude 與 Codex 兩邊一次到位。

### 為什麼拆 4 份（index/operating/setup/claude-state）

依「用途 × tool-agnostic 邊界」切：`operating`（偵測+操作）與 `setup`（bootstrap+轉換）是純 git 機制、tool-agnostic；`claude-state`（memory/transcripts/registry/settings/--bare）是 Claude 專屬，獨立成檔讓其他 tool 自然略過，未來他 tool 可加 `*-state.md` sibling。`index.md` 作路由，對 progressive disclosure 友善。

### 為什麼不再需要 `.chezmoitemplates` indirection

該 indirection 的存在理由是「同一 fragment 被多支 `.tmpl` 共用渲染」。收斂成單一份後，內容直接以純靜態 `.md`（無 template 指令）置於 `dot_agent/reference/bare-worktree/`，由 chezmoi 直接複製，無需 `.tmpl` 亦無需 `.chezmoitemplates` 中轉。

### 清理孤兒檔的判定依據

- `~/.claude/reference.md`：grep 全 source + live skills/commands 無 referrer，且內容（速查手冊）已過期（列出的 `opsx:*`、`code:review-spec/security/types` 等已不存在於現行 skill 清單）。
- `~/.claude/worklog-config.md`：`worklog-team-status` skill 內文已明寫「不讀取任何本地檔案（無 worklog-config.md…）」。
兩者皆 machine-local（非 chezmoi 管），移除僅 `rm` live 檔。

## Risks / Trade-offs

- **斷鏈風險**：任何遺漏的舊路徑引用會在 cwd 命中 layout 時讀不到檔。緩解：本次已 grep 全域找出所有 `bare-worktree-workflow` 引用（§7、dev-workflow L33/L44、兩 `.tmpl`）並全數納入變更；驗證階段以 `chezmoi diff` 與實際路徑存在性覆核。
- **`claude-state.md` 置於 tool-agnostic 目錄**：略有違和，但以檔頭標註 + index 路由說明化解；保持主題內聚優於拆散一份連貫文件。
