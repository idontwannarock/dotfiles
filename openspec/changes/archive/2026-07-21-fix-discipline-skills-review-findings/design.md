# Design: fix-discipline-skills-review-findings

## Context

修正來源:rework-dev-workflow-skills 的 comprehensive review。17 個候選 issue 經 confidence scoring 後,採用 Critical(A/I)+ Should-fix(B/C/D/E/J/F)+ Minor(G/H/M/Q/K/L)全修;排除 N(品味)、O(pre-existing drift,另案)、P(加註解即可)。

## Goals / Non-Goals

**Goals**:讓 worktree / finish-branch 被 agent 逐字執行也安全;拆掉 superpowers 殘留風險;補 name-map regression guard。
**Non-Goals**:不動 pre-existing spec drift(推進模式、registry 路徑 — 另開 drift-cleanup change);不移除 superpowers plugin 本體(仍屬 Change 2)。

## Decisions

- **D1 finish-branch 重構形狀**:選項表(Merge / Push+PR / Keep / Discard)之後,行為按「選項 × ARCH」列出;共通規則獨立成段 — (a) 任一命令失敗即停,不得繼續後續步驟;(b) dispose(worktree+branch)與 active_workflows row 移除只發生在「merge 已確認完成」或「使用者確認 Discard」之後;Keep 與 Push+PR(PR 未 merge)保留 worktree 與 row(row 標 status)。Discard 用 `branch -D` 前必須向使用者確認。
- **D2 worktree 起點與 registry**:normal 命令補 `main` 起點並保留「先確保 main 最新」;Register 段直接內嵌 arch 分派(normal 自動推導 / bare 用 autoMemoryDirectory key 查 registry),與 dev-workflow 2b 同語義,消除矛盾。
- **D3 Codex superpowers 安裝移除**:D7(plugin 保留)的理由是 Claude 端 episodic-memory 依賴;Codex 端無此依賴且已零引用,安裝步驟與註解一併移除。
- **D4 regression guard 放 chezmoi-author checklist**:「改動 shared body 或 wrapper 後,render 全部 wrappers 並 grep `<no value>`」— 放 authoring checklist 而非 hook(與既有「不用 hook 自動化」原則一致)。
- **D5 過渡護欄一句話**:user-system-prompt 加一行禁止使用被取代的 superpowers skills,plugin 移除後隨 Change 2 刪除。

## Risks / Trade-offs

- 修改 archived change 的文字(K)是動歷史紀錄 — 只更正客觀錯誤(不存在的檔案路徑敘述),不改決策內容。
- operating.md 縮段後,人工手動操作時需跳轉 finish-branch — 可接受,命令單一來源優先。
