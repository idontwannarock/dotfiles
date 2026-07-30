## ADDED Requirements

### Requirement: reference concept 檔帶 OKF v0.2 frontmatter

`~/.agent/reference/` 下每個 concept 檔（即所有非 reserved filename 的 `.md`）SHALL 以 YAML frontmatter 開頭，欄位為 `type`、`title`、`description` 三者，遵循 Open Knowledge Format v0.2。`description` 的值 SHALL 加雙引號，以免含冒號時被 YAML 解析為 mapping。

`type` SHALL 取自 `Playbook`（照著步驟做的程序）、`Reference`（機制與行為描述）、`Principle`（規範性原則）三者之一。新增第四個 `type` 前 SHALL 先確認三個既有值皆不適用。

此需求的適用範圍限於 `~/.agent/reference/`。OKF frontmatter SHALL NOT 寫入各 tool 有自身 schema 的位置（`~/.claude/skills/`、`~/.codex/skills/`、`~/.claude/memory/`），因該處要求 `name` + `description` 而與 OKF 的必填 `type` 不交集。

#### Scenario: 每個 concept 檔可被 OKF consumer 解析

- **WHEN** 掃描 `~/.agent/reference/` 下所有非 `index.md`、非 `log.md` 的 `.md`
- **THEN** 每檔以 `---` 起始的 YAML frontmatter 開頭，且可被標準 YAML parser 解析
- **AND** 每檔含非空的 `type`，其值為 `Playbook`、`Reference`、`Principle` 之一
- **AND** 每檔含 `title` 與加了雙引號的 `description`

#### Scenario: 不使用 lifecycle 欄位

- **WHEN** 檢視任一 concept 檔的 frontmatter
- **THEN** 不含 `status`（OKF §5.4 缺省即 `stable`，寫出為冗餘）
- **AND** 不含 `stale_after`（OKF §5.5 無預設值，缺此欄位即表示長青內容永不過期）
- **AND** 不含 provenance／trust 家族欄位（`sources`、`generated`、`verified`）

### Requirement: index.md 為 reserved filename，僅作目錄清單

依 OKF §3.1，`index.md` 與 `log.md` SHALL NOT 用作 concept document。`~/.agent/reference/` 下任一 `index.md` SHALL 只包含該目錄有哪些內容、以及何時該讀哪一份的路由資訊；任何會被 agent 當作答案引用的知識 SHALL 置於具名的 concept 檔。

`index.md` SHALL NOT 帶 frontmatter，唯一例外是 bundle root 的 `~/.agent/reference/index.md` MAY 帶 `okf_version`。

#### Scenario: bundle root index 宣告 OKF 版本並列出全部內容

- **WHEN** `chezmoi apply` 執行
- **THEN** `~/.agent/reference/index.md` 存在，frontmatter 僅含 `okf_version: "0.2"`
- **AND** 其內容列出 `bare-worktree/`、`local-files/`、`tdd/` 三個子目錄與 root 層的 `dev-workflow-isolation.md`

#### Scenario: local-files 的機制知識脫離 index.md

- **WHEN** 讀者開啟 `~/.agent/reference/local-files/`
- **THEN** `store.md` 存在且帶 `type: Reference` frontmatter，內含 authority model（global store 為備份、in-folder copy 為來源）、store layout、managed files、`localfiles` helper 與 agent read-fallback rule
- **AND** `index.md` 僅為指向 `store.md` 與 `setup.md` 的目錄清單，不帶 frontmatter
- **AND** 無任何檔案連結指向已不存在的 `local-files/index.md` 內容段落

## MODIFIED Requirements

### Requirement: 跨 tool 共用 reference 置於中立的 ~/.agent/reference/

跨 AI tool 共用的 reference 文件 SHALL 由 chezmoi source 的 `dot_agent/` 目錄管理，部署到中立的 `~/.agent/reference/` 位置，而非任一特定 tool 的家目錄（`~/.claude/`、`~/.codex/`）。同一份知識 SHALL NOT 在多個 per-tool 家目錄各存一份副本。

#### Scenario: bare-worktree reference 部署到 ~/.agent

- **WHEN** `chezmoi apply` 執行
- **THEN** `~/.agent/reference/bare-worktree/index.md`、`operating.md`、`setup.md`、`claude-state.md` 四檔存在
- **AND** `~/.claude/bare-worktree-workflow.md` 與 `~/.codex/bare-worktree-workflow.md` 不再存在

#### Scenario: 純靜態檔無 template 中轉

- **WHEN** 新增 `~/.agent/reference/` 下的 reference 檔
- **THEN** source 端為純 `.md`（無 `.tmpl` 後綴、無 Go template 指令），由 chezmoi 直接複製
- **AND** 不經由 `.chezmoitemplates/` fragment 中轉
- **AND** OKF frontmatter 為固定字面值（無機器名、路徑或條件分支），不構成引入 `.tmpl` 的理由
