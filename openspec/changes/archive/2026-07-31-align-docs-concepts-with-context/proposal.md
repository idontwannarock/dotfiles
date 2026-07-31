## Why

同一個判斷依據目前重複寫在 `docs/`、`openspec/specs/`、`.chezmoitemplates/skills/` 與 `context/` 之間,改一次事實要動多個檔。已確認 8 處實例,例如「`arch-review` 標 `disable-model-invocation` 的理由」同時存在於 `docs/claude-code.md:479`、`openspec/specs/arch-review/spec.md:9` 與 `context/principles.md:15`;「Codex frontmatter 需嚴格 YAML」在 `docs/codex-cli.md:38` 與 `context/principles.md:18` 逐字同義。

`context/` bundle 上線後(PR #42)已有承載這類知識的正確位置,但 `docs/` 端的舊副本沒有清掉,而且沒有任何規範擋下一次再寫回去 —— `project-context` 的內容邊界只涵蓋 `specs/`、`design.md`、`context/` 三處,`docs/` 不在其中。

## What Changes

- 以三步機械規則逐句掃過 `docs/` 下 14 份文件(2109 行),把**可一般化的判斷依據**從 `docs/` 移除,權威保留在 `context/`:
  1. 讀者能照做 → 操作,留 `docs/`
  2. 不能照做但換一個工具/情境即不成立 → 只解釋單一案例,留 `docs/`
  3. 不能照做且換情境仍成立 → 屬 `context/`;`context/` 已有對應條目就刪句,沒有就標 `<!-- evergreen-candidate -->` 進 `design.md` 待 sync/archive 裁定
- 被改動的 docs 檔在標題下方加一行指向 `context/`,不做逐處硬連結(避免綁定條目文字)
- `project-context` 的內容邊界 requirement 由三分法擴為四分法,補上 `docs/` 這一格
- 收緊 `bootstrap-docs` 的 Purpose:它實際管的是**入口路徑**(6 條 requirement 有 5 條斷言 README),現行措辭「README / docs 的 bootstrap 文件」讓人誤以為它納管整個 `docs/`

不做的事:不搬安裝步驟與故障排除(它們是可驗收的 WHAT,已受 `bootstrap-docs` 等 spec 把關,且會隨上游漂移,不符 `context/` 的長青承諾);不動 `bootstrap-docs` 任何 requirement;`context/principles.md` 的精簡另開一輪。

## Capabilities

### New Capabilities

無。

### Modified Capabilities

- `project-context`: 內容邊界 requirement 由三分法擴為四分法 —— `docs/` SHALL 承載操作步驟與單一案例的理由,SHALL NOT 承載可一般化的判斷依據

## Impact

- `docs/` 下 14 份文件(`bash.md`、`claude-code.md`、`claude-zai-wrapper.md`、`codex-cli.md`、`corp-ssh-setup.md`、`corp-ssh-setup-windows.md`、`git-credentials.md`、`powershell.md`、`renovate.md`、`rtk.md`、`ssh.md`、`starship.md`、`user-scripts.md`、`vim.md`);概念密度最高的是 `claude-code.md` 的 Handoff(406-460)與 Arch Review(461-512)兩章
- `context/principles.md` / `context/glossary.md`:少量新增,多數情況不動
- `openspec/specs/bootstrap-docs/spec.md`:Purpose 一行(無 requirement 變更,故不列為 Modified Capability)
- 範圍外:`docs/superpowers/specs/` 下兩份共 55KB 的 corp-ssh 歷史設計文件 —— 性質等同 archived `design.md`,套規則等於改寫歷史;`README.md` —— 已於 347 行指向 `context/`
- 既有 inbound 連結須維持:`codex-cli.md:36`→`claude-code.md`、`claude-zai-wrapper.md:193-195`、README 目錄表
