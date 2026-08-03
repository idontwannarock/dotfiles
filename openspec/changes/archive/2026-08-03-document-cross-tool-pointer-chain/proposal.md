## Why

跨工具 parity 的「shared body + 薄指標」架構,在 `context/` 裡只有抽象描述:`glossary.md` 說有「每工具一個薄的 name-map wrapper」,`principles.md` 說「權威 body 一份在 `~/.agent` / `.chezmoitemplates`」,但**沒有任一處指名這條鏈實際上是哪些檔案**。要接第三個工具(Antigravity)時,得先反推一次鏈的形狀才動得了手。

這兩條事實原本孤懸在 auto-memory `project-cross-tool-targets`。memory 是 point-in-time 觀察、不受版控、也不在需求分析的閱讀路徑上;鏈的形狀屬於 repo 的模組邊界知識,該由 `context/` 承載。

## What Changes

- `context/glossary.md` 的 **cross-tool parity / name-map wrapper** 條目補上這條鏈的三個具名檔案與從屬關係(`.chezmoitemplates/user-system-prompt.md` → `dot_claude/CLAUDE.md.tmpl`、`dot_codex/AGENTS.md.tmpl`),並補上「共用 body 之外的知識放 `~/.agent/reference/`」這半。
- `context/principles.md` 的「跨工具 parity = shared body + 薄指標」條目補上接新工具的前置檢查:先確認該工具實際的 instruction-file 慣例,不要假設檔名。
- 兩處皆為**就地擴充既有條目**,不新增條目、不新增分組——`principles.md` 維持 23 條分四組(PR #45 的結構)。
- 落地後刪除 auto-memory `project-cross-tool-targets.md` 與 `MEMORY.md` 的對應索引行(該 memory 屆時無唯一內容)。

## Capabilities

### New Capabilities

無。

### Modified Capabilities

- `project-context`:新增一條 requirement「auto-memory 不承載 repo-level 長青知識」。

  兩處文件擴充本身**不改任何 requirement** —— 「內容依知識性質分檔」與「內容邊界與晉升閘門」的三步規則已完整涵蓋,本次只是套用它們。

  但盤點時發現既有的四分法(`openspec/specs/` / `design.md` / `docs/` / `context/`)**獨漏 auto-memory**,而本案的起因正是一條 repo-level 長青事實在 auto-memory 裡孤懸三個月、無人察覺。補上這條邊界直接防止同類斷鏈再發生,且有實作背書(本次即實例)。

## Impact

- `context/glossary.md`、`context/principles.md` —— 各一處句子級擴充。
- 不觸及 `.chezmoiroot` 之下的 source,**不需要 `chezmoi apply`**;`context/` 不部署到任何機器。
- `~/.claude/memory/-home-howardwang-ws-github-dotfiles/` 的 `project-cross-tool-targets.md` 與 `MEMORY.md`(版控之外,收尾步驟)。
