## Context

`openspec/project.md` 的種子已 bootstrap 並 commit。本 change 把它接進開發流程,使其被讀取、且不腐爛。設計共識來自先前一輪 grill(記於 memory `project-md-context-doc`)。

現況約束:
- `grill`、`dev-workflow` 的 skill body 是 chezmoi shared-body(`home/.chezmoitemplates/skills/{grill,dev-workflow}.md`),Claude 與 Codex 共用同一份、經 name-map wrapper 部署。編輯落在 chezmoi source。
- openspec 1.1.1 原生 context 承載只有 `config.yaml: context:`(YAML scalar),無流程 touchpoint。
- 兩個 skill body 的行為分別由 main spec `discipline-skills`(grill)與 `workflow-instructions`(flow)描述,改行為必須同步改 spec 以免漂移。

## Goals / Non-Goals

**Goals:**
- 讓 `project.md` 在需求分析階段被讀、在 sync/archive 階段被寫,Small/Large 皆涵蓋。
- 內容邊界明確(specs=WHAT / design=一次性 / project.md=domain+原則),有晉升閘門防垃圾場。
- 純文件/流程紀律變更,零執行期影響。

**Non-Goals:**
- 不動 openspec 原生 `config.yaml: context:`(明確不依賴它)。
- 不為每個 Small change 硬塞 project.md 更新(只在有長青候選時晉升)。
- 不新增 name-map token、不改 wrapper 機制(編輯僅在 shared body 的純文字段落)。

## Decisions

- **載體 = `openspec/project.md`,由自家 workflow 主動讀,不靠 openspec 原生注入。** 替代方案 `config.yaml: context:` 塞不下會長大的人類可讀文件且全 repo 皆空;`repo 根 CONTEXT.md` 脫離 openspec/。選 project.md:與 specs 一起版控、tool-agnostic、markdown 好讀。
- **寫入掛 `sync-specs`/archive,不掛 grill。** grill 在實作前,其時的原則只是假設,早寫會「把願望寫成事實」並易被濫用致文件與事實不符;sync/archive 寫的都有實作背書。且兩條 flow 都有 sync/archive,一次涵蓋。替代(grill 當下寫)被否決。
- **grill 只「讀 + 標記候選」不寫。** grill 開場讀 project.md 當 grounding;把長青候選以 `<!-- evergreen-candidate -->` 標進 design.md 的 `## Decisions`;archive 時逐條對照實際 shipped 再晉升或丟棄。這保住「新鮮詞彙不遺失」又不重開濫用門。
- **spec 拆分**:新 capability `project-context-doc` 只講「文件是什麼 + 內容邊界/晉升閘門」;讀/寫的**機制**分別掛回 `discipline-skills`(grill)與 `workflow-instructions`(flow),避免概念重複。

## Risks / Trade-offs

- [Small change 偶爾漏晉升 project.md] → 接受;晉升條件本就是「有長青候選才做」,漏掉的多半不該進 project.md。
- [改 shared-body 可能誤傷 name-map wrapper 渲染] → 本次僅改純文字段落、不加 token;verify 階段 render 全 wrappers + grep no-value 標記(chezmoi-author 既有 guard)。
- [spec 與 skill body 漂移] → 同一 change 內同步改 spec 與 body;openspec validate + review 把關。

## Migration Plan

1. 改 shared-body(grill.md、dev-workflow.md)。
2. 改 main spec delta(discipline-skills、workflow-instructions)+ 新 capability spec。
3. `chezmoi apply` → 確認 `~/.claude/skills/{grill,dev-workflow}/SKILL.md` 與 Codex 對應檔含新文字、wrapper 正常渲染(**先本機測**)。
4. sync-specs → archive → commit → review。
- Rollback:純文件,revert commit 即可。

## Open Questions

- 無。設計已於上一輪 grill 收斂。

## 測試 seam(供 verify 用)

無傳統單元測試 seam(純文件)。驗證證據 = (a) `chezmoi apply` 後兩個 SKILL.md 含新段落;(b) name-map wrapper 全數渲染無 no-value 標記;(c) `openspec validate` 通過。
