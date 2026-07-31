## Why

`openspec/project.md` 是長青的專案 context 文件,但它放在 `openspec/` 底下暗示它是 OpenSpec CLI 的一部分 —— 實際上 CLI 1.1.1 完全不依賴這個路徑。位置錯誤帶來兩個代價:讀者以為它受 CLI 管轄而不敢動,且它與 machine-level 的 `~/.agent/reference/` 承載同類知識卻用兩種格式。

上一輪(PR #41)已把 `~/.agent/reference/` 轉成 OKF v0.2 bundle。把 repo-level context 也搬成同格式的 bundle,可讓兩層 context 共用同一組 `type` 詞彙、同一套 `index.md` 慣例,agent 只讀 frontmatter 就能判斷相關性。

## What Changes

- `openspec/project.md`(單檔 88 行)搬到 repo root 的 `context/`,拆成 5 個檔:
  - `index.md` — 純路由,唯一 frontmatter 為 `okf_version: "0.2"`
  - `overview.md`(`type: Reference`)— 原「這是什麼」段
  - `glossary.md`(`type: Reference`)— 原「詞彙表」段
  - `principles.md`(`type: Principle`)— 原「反覆適用的原則與約束」段
  - `capability-map.md`(`type: Reference`)— 原「方位」段,重點由列舉 spec 名改為**分組與邊界**
- 內容原樣搬移。除結構逼出的改動(拆檔、加 frontmatter、標題升級、方位段改寫)外不編輯字句。
- OKF 格式規則從 `agent-reference-layout` 抽出為獨立 capability,供兩個 bundle 共用;原「適用範圍限於 `~/.agent/reference/`」的守衛句放寬為「本 repo 宣告的 OKF bundle」,對 tool 自有 schema 位置的禁令不變。
- `project-context-doc` capability 更名為 `project-context`,內容改為描述 `context/` bundle 而非單一檔案。
- 9 處 inbound 引用改指新路徑:4 份 spec、2 份 `docs/`、3 份 `home/.chezmoitemplates/skills/`。
- README 增加一行指向 `context/`。不新增 root `CONTEXT.md`。

## Capabilities

### New Capabilities

- `okf-bundle-conventions`: 本 repo 各 OKF v0.2 bundle 共用的格式規則 —— frontmatter 欄位子集、`type` 詞彙與擴充閘門、`description` 引號規則、`index.md` 的 reserved 地位與內容邊界、bundle root 的 `okf_version` 宣告,以及適用範圍守衛。
- `project-context`: repo-level 長青專案 context 的存在、位置、內容三分法邊界與晉升閘門。取代 `project-context-doc`。

### Modified Capabilities

- `agent-reference-layout`: 移出 OKF 格式規則(改為引用 `okf-bundle-conventions`),保留部署位置與檔案拆分規則。
- `arch-review`: 判準來源由 `openspec/project.md` 改為 `context/glossary.md`;不寫入該檔的禁令一併改指新路徑。
- `discipline-skills`: grill 開場讀取的 domain grounding 由 `openspec/project.md` 改為 `context/` bundle。
- `workflow-instructions`: sync/archive 階段的長青候選晉升目標由 `openspec/project.md` 改為 `context/` bundle。

### Removed Capabilities

- `project-context-doc`: 由 `project-context` 取代(更名,非刪除功能)。

## Impact

- **新增**:`context/`(repo root,`.chezmoiroot=home/` 之外,不部署到任何機器)
- **刪除**:`openspec/project.md`
- **文件**:`docs/claude-code.md`、`docs/codex-cli.md`、`README.md`
- **部署中的 skill body**:`home/.chezmoitemplates/skills/{arch-review,grill,dev-workflow}.md` —— 這三份會經 chezmoi 渲染到使用者機器,路徑改動需 `chezmoi apply` 才生效
- **不影響**:OpenSpec CLI(不依賴此路徑)、`openspec/specs/` 與 `openspec/changes/` 的既有結構、archived changes(凍結,不回溯改寫)
