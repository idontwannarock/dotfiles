## Why

OpenSpec 命名了一層「專案 context」(`config.yaml: context:`)卻沒給好載體、也沒給任何流程 touchpoint 去維護它——結果本機每個 repo 的 context 都空著。這代表「未來需求分析」缺一份長青、人可讀、跨工具的專案背景;現況只能重讀整份程式碼、或掃過已 archive 的 change 文件才拼得出一致的 domain 認知與決策原則。本 change 補上這一層,並把它接進開發流程,使其不腐爛。

## What Changes

- 引入 `openspec/project.md` 作為長青專案 context 文件(bootstrap 種子已 commit)。它與 `CLAUDE.md`/`AGENTS.md` **關注點不同**:後者是給 AI 工具每 session 固定載入的操作性指令;`project.md` 是需求/domain 知識,需要時查閱。
- 確立**內容三分法邊界**:`specs/` = 系統「做什麼」(WHAT、可驗收);change 的 `design.md` = 一次性方案選擇(隨 change archive);`project.md` = domain 背景 + 詞彙表 + **反覆適用的**長青原則。附**晉升閘門**:design 決策唯有上升為反覆適用原則才提煉進 `project.md`。
- `grill` skill:訪談開場**讀** `project.md` 當 grounding(併入其「事實自己查」紀律);把長青候選以 tag **標記進 `design.md`**;**明確不寫** `project.md`。
- `dev-workflow` skill:在 `openspec-sync-specs`/archive 步驟(Small 與 Large 兩條 flow)新增「把 `design.md` 的長青候選晉升進 `openspec/project.md`」。
- 不依賴 openspec 原生 `config.yaml: context:` 注入(1.1.1 只認 YAML scalar、無流程 touchpoint);改由自家 workflow 主動讀寫。

## Capabilities

### New Capabilities
- `project-context-doc`: `openspec/project.md` 的存在、目的/讀者、內容邊界(三分法 + 晉升閘門),以及「讀在需求分析階段、寫在 sync/archive 階段」的 lifecycle 契約。

### Modified Capabilities
- `discipline-skills`: `grill` 訪談紀律新增「讀 `project.md` 當 grounding」與「長青候選標記進 `design.md`、不寫 `project.md`」。
- `workflow-instructions`: 核心 flow 在 sync-specs/archive 新增「晉升長青候選進 `project.md`」步驟,Small/Large 皆涵蓋。

## Impact

- 新增:`openspec/project.md`(種子已 commit)。
- 修改(chezmoi source,Claude+Codex 共用 shared body):`grill` 與 `dev-workflow` 的 skill body(`home/.chezmoitemplates/skills/`)。
- 修改:main specs `discipline-skills`、`workflow-instructions`。
- 部署注意:改的是 shared-body,`chezmoi apply` 後傳播到 `~/.claude` 與 `~/.codex`;遵守 dotfiles「先本機測、確認生效再回寫 source」。
- 無程式碼/執行期影響;純文件與流程紀律變更。
