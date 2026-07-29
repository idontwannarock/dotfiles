## Context

本 repo 已有一套跨工具的品質關卡,但它們**全部以 diff 為輸入**:`review-*` 系列看 branch 差異、`verify-done` 跑驗證命令、`simplify` 只看剛改的 code。架構熵增是跨 change 累積的現象,在 diff 視野中結構性不可見。

設計上可借鑑的既有基礎建設有三塊,本次全部重用而非重造:

1. **handoff/pickup 檔案約定** — `~/.agent/handoffs/<repo-slug>/<ID>.md`,ID 格式 `YYYY-MM-DD-HHMM__<slug>`,repo-slug 為絕對路徑把 `:`/`\`/`/`/`.` 換成 `-`。
2. **pickup 的實際契約** — 經查證,`pickup` 的檔案解析是**格式無關的**(依檔名 glob),它只對兩個段落有行為依賴:`## Suggested skills`(逐一呼叫)與 `## Next steps`(接續執行)。其餘內容形狀自由。
3. **cross-tool parity 機制** — shared body 放 `.chezmoitemplates/skills/<name>.md`,每個工具一個薄 wrapper。

關鍵環境事實(影響判準設計):目前 5 個 repo 中**只有 dotfiles 有 `openspec/project.md`**;`ai-tools-list`、`chat_setting_api`、`sensitive-content-detection-and-masking` 有 openspec 但無 project.md,`shoalter-ai-toolkit` 連 openspec 都沒有。而 dotfiles 本身是設定檔集合,恰好是最不需要架構體檢的那個。

## Goals / Non-Goals

**Goals:**

- 提供一個手動觸發、整庫視野的架構體檢入口,補上 diff 層級檢查的盲區。
- 產出可被 `/pickup` 直接接手的候選清單,讓「診斷」與「執行」之間不需要人工轉譯。
- 在有無 `project.md` 的 repo 都能運作,判準品質隨可用資訊分層降級,且降級要對使用者可見。
- 掃描成本可控:不因為 repo 大就無限膨脹 context。

**Non-Goals:**

- 不自動執行重構。體檢只診斷,開刀與否是使用者的決定。
- 不掛進 dev-workflow / finish-branch / archive 任何自動觸發點。
- 不寫入 `openspec/project.md`(現行 `project-context-doc` spec 規定它只在 sync/archive 寫入,連 grill 都明文 SHALL NOT 寫)。
- 不修改 `pickup`。它已經格式無關,不需為本案調整。
- 不做歷次體檢的趨勢追蹤 / 比對。

## Decisions

### D1. 產出為 handoff 相容文檔,由 arch-review 自己寫

體檢結果寫入 `~/.agent/handoffs/<repo-slug>/<ID>.md`,slug 使用 `arch-review`(即 ID 形如 `2026-07-29-1530__arch-review`),主體是 findings,但**必須**包含 `## Suggested skills` 與 `## Next steps` 兩段。

*替代方案:* (a) 呼叫 `handoff` skill 代工 —— 否決,`handoff` 的紀律是「≤50 行、引用而非重述、不複製既有 artifact 內容」,而 findings 本身就是新資訊、沒有別的檔可引用,兩者的 anti-patterns 正面衝突。(b) 擴充 `handoff` 支援雙模式 —— 否決,把一個已上線且乾淨的 skill 變成雙模式,風險不對稱。(c) 純對話不寫檔 —— 否決,使用者明確要求要能 pickup 續做。

<!-- evergreen-candidate -->
**pickup 契約**:`~/.agent/handoffs/` 下的文檔只要含 `## Suggested skills` 與 `## Next steps` 兩段即可被 `/pickup` 接手,其餘內容形狀自由。這使該目錄可以承載 session-state 以外的產物。

### D2. 純手動觸發

不掛任何流程。體檢的正確頻率是「數個 change 累積後」或「里程碑」,不是「每條 branch」。掛進流程會變成每次都跳出的雜訊,而**被學會忽略的 gate 比沒有 gate 更糟** —— 它同時消耗注意力又提供虛假的安全感。

### D3. 部署照 handoff 模式(command 而非 skill)

Claude 端為 `home/dot_claude/commands/arch-review.md.tmpl` 並標 `disable-model-invocation: true`;Codex 端(無 command 概念)為 `home/dot_codex/skills/arch-review/SKILL.md.tmpl`;兩者共用 `home/.chezmoitemplates/skills/arch-review.md`。

<!-- evergreen-candidate -->
**能力的部署形狀由觸發模式決定**:純手動觸發的能力走 command + `disable-model-invocation: true`(Claude)/ skill(Codex);要讓模型自行判斷時機的走雙邊 skill。這條分界既有實作已在遵循(handoff/pickup vs 六個 discipline skills),但未被文件化。

*理由:* 若做成模型可自行呼叫的 skill,模型可能在使用者沒要求時自行啟動整庫掃描,成本高且不受控 —— 這正是 `disable-model-invocation` 存在的目的。

### D4. 判準來源分層,降級要可見

| 情境 | 判準 | 報告中的標示 |
|------|------|------------|
| 有 `openspec/project.md` | 以其詞彙表為模組邊界的權威判準 | 標為權威 |
| 無 `project.md` | 從 codebase 推斷 domain 語言(目錄結構、型別/類別名、導出介面) | **明示為推斷而非權威** |

*替代方案:* (a) 硬性要求 project.md —— 否決,等於現在只有 dotfiles 能用。(b) 體檢順便產生 project.md —— 否決,直接違反 `project-context-doc` 已上線的 spec。

降級可見性是硬要求:一份沒有標明判準來源的架構評斷,讀者無從判斷該給它多少權重。

### D5. 兩階段掃描

**階段一(廉價盤點,不讀檔案內容)**:目錄樹、檔案規模分布、依賴方向、名稱重複訊號。
**階段二(深挖)**:據盤點結果選 3-5 個可疑區才讀內容。

支援可選 path 參數縮限(`/arch-review src/payment`)。

*替代方案:* (a) 一律要求指定範圍 —— 否決,模組**之間**的邊界問題正是熵增最常發生處,限定單一模組就掃不到。(b) subagent fan-out 平行深掃 —— 否決,使用者全域 CLAUDE.md 要求 subagent 需明確授權;且兩階段已能在成本與覆蓋間取得平衡。

### D6. 只提候選,不動手

輸出為排序過的重構候選,每項含:問題陳述、證據(檔案路徑 + 具體事證)、影響範圍、建議動作。不執行任何修改。這條貫串全案,也是名稱選 `arch-review` 而非 mattpocock 原名 `improve-codebase-architecture` 的原因 —— 「improve」暗示會動手,與此邊界矛盾。

### D7. 新開 `arch-review` capability spec

不併入 `discipline-skills`(該 spec 涵蓋的是六個模型可自行呼叫的紀律 skill,arch-review 是手動 command,語意不符)。

註:`handoff`/`pickup` 目前完全沒有 spec 覆蓋 —— 這是既有缺口而非刻意設計,不作為本案的先例。

### D8. 一併修正 handoff.md.tmpl 的 description

`home/dot_claude/commands/handoff.md.tmpl` 的 description 寫「under `.claude/handoffs/`」,但其 body 早已改為 `~/.agent/handoffs/`。本案重用同一套約定,若不修正會有兩處說法互相矛盾。

## Risks / Trade-offs

- **[報告過期]** 體檢結果是某個時間點的快照,codebase 持續變動後即失效 → 產出帶時間戳的 ID,且不做歷次比對(明確非目標);候選要動手時走 OpenSpec change,以 change 為準而非以報告為準。
- **[無 project.md 時判準品質下降]** 推斷出的 domain 語言可能與使用者心智模型不符,產生噪音候選 → 報告明示判準為推斷;候選一律附證據,使用者可自行判斷是否採信。
- **[大 repo 成本仍可能失控]** 階段一雖廉價,超大 repo 的目錄樹本身就可能很大 → 支援 path 參數縮限;階段二硬性限制 3-5 個深挖區,不得無限展開。
- **[候選品質參差]** 架構判斷本質主觀,可能提出使用者早已權衡過並刻意接受的設計 → 排序 + 附證據,使用者可快速跳過;不做自動執行,誤判成本僅止於閱讀時間。
- **[跨工具行為漂移]** Claude 走 command、Codex 走 skill,兩邊 frontmatter 不同 → shared body 承載全部行為,wrapper 只做 name-map 與 frontmatter;Codex frontmatter 的 description 含冒號必須加引號(既有原則)。

## Migration Plan

純新增,無既有行為被取代,無 rollback 需求。`chezmoi apply` 後 `/arch-review` 於 Claude 可用、`arch-review` skill 於 Codex 可用。唯一的修改項(D8)是 description 字串修正,不改變任何行為。

## Open Questions

無。grill 階段 8 個決策已全數確認。
