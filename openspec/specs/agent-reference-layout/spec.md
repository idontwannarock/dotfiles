# agent-reference-layout Specification

## Purpose
定義跨 AI tool 共用的 reference 文件配置:由 chezmoi `dot_agent/` 部署到中立的 `~/.agent/reference/`(脫離任一 tool 的家目錄),依用途與 tool-agnostic 邊界拆分為多檔,並要求各 tool 的 top-level prompt 以絕對路徑指向共用的單一真相,使單一修改對所有 tool 生效。此目錄同時是一個 Open Knowledge Format (OKF) v0.2 bundle;其格式規則見 `okf-bundle-conventions`,本 spec 只規範此 bundle 專屬的內容組成。
## Requirements

### Requirement: 跨 tool 共用 reference 置於中立的 ~/.agent/reference/

跨 AI tool 共用的 reference 文件 SHALL 由 chezmoi source 的 `dot_agent/` 目錄管理，部署到中立的 `~/.agent/reference/` 位置，而非任一特定 tool 的家目錄（`~/.claude/`、`~/.codex/`）。同一份知識 SHALL NOT 在多個 per-tool 家目錄各存一份副本。

#### Scenario: bare-worktree reference 部署到 ~/.agent

- **WHEN** `chezmoi apply` 執行
- **THEN** `~/.agent/reference/bare-worktree/` 下的 reference 檔存在，至少包含 `index.md`、`operating.md`、`setup.md`、`claude-state.md`（此處不宣告完整清單，檔案組成隨拆分演進）
- **AND** `~/.claude/bare-worktree-workflow.md` 與 `~/.codex/bare-worktree-workflow.md` 不再存在

#### Scenario: 純靜態檔無 template 中轉

- **WHEN** 新增 `~/.agent/reference/` 下的 reference 檔
- **THEN** source 端為純 `.md`（無 `.tmpl` 後綴、無 Go template 指令），由 chezmoi 直接複製
- **AND** 不經由 `.chezmoitemplates/` fragment 中轉
- **AND** OKF frontmatter 為固定字面值（無機器名、路徑或條件分支），不構成引入 `.tmpl` 的理由

### Requirement: bare-worktree reference 依用途拆分為多檔

bare-worktree reference SHALL 拆分為多個聚焦檔案，以 `index.md` 作路由入口，並依 tool-agnostic 與 tool-specific 邊界分檔。

#### Scenario: tool-agnostic 與 Claude 專屬內容分離

- **WHEN** 讀者開啟 `~/.agent/reference/bare-worktree/`
- **THEN** `operating.md` 與 `setup.md` 僅含 tool-agnostic 的 git 機制（偵測、操作規則、bootstrap、轉換）
- **AND** Claude 專屬內容（auto-memory、transcripts、workflow registry、`--bare` 釐清）集中於 `claude-state.md`，且 `index.md` 註明其為 Claude 專屬、他 tool 可跳過

#### Scenario: 拆分後內容完整無遺漏

- **WHEN** 比對拆分後四檔與原 `bare-worktree-workflow.md`
- **THEN** 原檔每一段落皆對應到四檔之一，無內容遺失

### Requirement: top-level prompt 以絕對路徑指向共用 reference

各 AI tool 的 top-level prompt SHALL 以絕對路徑 `~/.agent/reference/...` 指向共用 reference，而非相對於 prompt 檔的「alongside this file」。共用指標 SHALL 置於被多 tool 渲染的 fragment，使單一修改對所有 tool 生效。

#### Scenario: §7 指標一處改、雙 tool 生效

- **WHEN** `chezmoi apply` 渲染 `~/.claude/CLAUDE.md` 與 `~/.codex/AGENTS.md`
- **THEN** 兩者的 bare+worktree 段落皆指向 `~/.agent/reference/bare-worktree/index.md`
- **AND** 該指標僅在共用 fragment `user-system-prompt.md` 維護一份

#### Scenario: skill 內的 reference 連結指向新路徑

- **WHEN** `dev-workflow` skill 引用 bare-worktree reference
- **THEN** 連結指向 `~/.agent/reference/bare-worktree/` 下存在的檔案（registry 相關 → `claude-state.md`，一般入口 → `index.md`）
- **AND** 無任何連結指向已移除的 `~/.claude/bare-worktree-workflow.md`

### Requirement: ~/.agent/reference/ 為 OKF v0.2 bundle

`~/.agent/reference/` SHALL 為一個 OKF v0.2 bundle,其 frontmatter 欄位、`type` 詞彙、`index.md` 的 reserved 地位與內容邊界 SHALL 遵循 `okf-bundle-conventions`,本 spec SHALL NOT 重述該格式規則。

本 spec 僅規範此 bundle 專屬的內容組成:哪些知識屬於哪個檔、root `index.md` 涵蓋哪些項目。

#### Scenario: bundle root index 涵蓋全部內容

- **WHEN** `chezmoi apply` 執行
- **THEN** `~/.agent/reference/index.md` 存在,frontmatter 僅含 `okf_version: "0.2"`
- **AND** 其內容涵蓋 bundle 下全部 concept:有自身 `index.md` 的子目錄以目錄形式連結,無 `index.md` 的子目錄直連其中檔案,root 層的檔案直連

#### Scenario: local-files 的機制知識脫離 index.md

- **WHEN** 讀者開啟 `~/.agent/reference/local-files/`
- **THEN** `store.md` 存在且帶 `type: Reference` frontmatter,內含 authority model(global store 為備份、in-folder copy 為來源)、store layout、managed files、`localfiles` helper 與 agent read-fallback rule
- **AND** `index.md` 僅為指向 `store.md` 與 `setup.md` 的目錄清單,不帶 frontmatter

#### Scenario: bare-worktree 的架構判準脫離 index.md

- **WHEN** 讀者開啟 `~/.agent/reference/bare-worktree/`
- **THEN** `scope.md` 存在且帶 `type: Reference` frontmatter,內含此 reference 只涵蓋一種架構的判準:`basename "$(git rev-parse --git-common-dir)"` 的 `.git` vs `.bare` 分派、layout×discipline 的 2×2 空間、以及未填格子出現時的處置
- **AND** `index.md` 僅含簡短的範圍摘要與「When to read which file」路由表,該表包含 `scope.md` 一列
- **AND** `index.md` 不含 dispatch 規則、2×2 分析或任何前瞻決定的內文
