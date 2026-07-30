## Why

`~/.agent/reference/` 已經是「一個目錄的 markdown + `index.md` 漸進揭露」的形狀，但每個檔案都沒有任何 machine-readable 的 metadata：agent 必須把整檔讀進來才知道這份文件是什麼、該不該讀。Google Cloud 的 Open Knowledge Format (OKF) v0.2 正好標準化了這個形狀，且規範明文要求 consumer「MUST NOT reject unknown `type`／缺 `index.md`／broken links」，導入零風險：不支援 OKF 的 tool 依舊把它當普通 markdown 讀。

導入後 agent 只讀 frontmatter 就能判斷相關性，且這批知識變成可攜的 OKF bundle——與既有的「`~/.agent` 共用 body + per-tool thin pointer」架構同一個方向。

## What Changes

- 為 `~/.agent/reference/` 下每個 **concept 檔**加上 OKF v0.2 frontmatter，欄位限縮為 `type` / `title` / `description` 三個。
- 不使用 `status` 與 `stale_after`：OKF §5.4 定義缺省 `status` 即 `stable`（寫了是冗餘），§5.5 的 `stale_after` 無預設值且刻意只支援絕對日期而非週期性複審——「不寫」正是 OKF 表達長青內容的方式。
- 新增 bundle root `~/.agent/reference/index.md`，承載 `okf_version: "0.2"`（OKF §8：只有 bundle-root index 可帶此鍵），並作為整個 reference 的單一入口。
- **BREAKING**（僅內部連結）：`local-files/index.md` 依 OKF §3.1 不得作為 concept document（`index.md` 是 reserved filename，MUST NOT），其實質內容搬到 `local-files/store.md`，原路徑改為薄的目錄清單。
- 建立一組最小的 `type` 詞彙：`Playbook`（照著做的程序）、`Reference`（機制描述）、`Principle`（規範性原則）。
- 修正一個 inbound 連結（`bare-worktree/claude-state.md` → `../local-files/store.md`）。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `agent-reference-layout`: 新增「concept 檔須帶 OKF v0.2 frontmatter」與「`index.md` 為 reserved filename、僅作目錄清單」兩條需求；既有的「純靜態 `.md` 無 template 中轉」需求不變（frontmatter 是靜態內容，不引入 `.tmpl`）。原 scenario 中「`~/.agent/reference/bare-worktree/index.md`…四檔存在」的斷言仍成立。

## Impact

- `home/dot_agent/reference/` 全部 9 個 `.md`（8 個加 frontmatter、1 個拆分）＋新增 2 檔（root `index.md`、`local-files/index.md`）。
- `home/dot_agent/reference/bare-worktree/claude-state.md` 的一個相對連結。
- `openspec/specs/agent-reference-layout/spec.md`。
- **不影響**：`home/.chezmoitemplates/` 下的 skill 模板與 `user-system-prompt.md`——它們指向的 `bare-worktree/index.md`、`operating.md`、`claude-state.md`、`tdd/*.md`、`dev-workflow-isolation.md` 路徑全部不變。
- **不影響** chezmoi 部署機制：純靜態檔複製，無新增 template、無新增 script。
- 無 runtime 相依：OKF 不需要任何 SDK、CLI 或 validator 才能被消費。
