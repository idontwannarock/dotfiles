## Why

現有的品質關卡全部針對 **diff**:`review-surgical` / `review-comprehensive` / `review-uncommitted` 看 branch 差異,`verify-done` 跑測試,`simplify` 只看剛改的 code。沒有任何一關會退一步看整個 codebase 的模組邊界與重複實作。

而架構熵增的特性正是**每個 diff 單看都合理,累積數十個 change 之後才壞掉** —— 這類問題在 diff 層級的檢查中結構性地不可見。缺的是一個定期、整庫、只診斷不開刀的體檢入口。

## What Changes

- 新增 `arch-review` 能力:手動觸發的整庫架構體檢,產出排序過的重構候選 + 證據,**不自動修改任何 code**。
- 掃描分兩階段:先做廉價的全庫結構盤點(目錄樹、檔案規模、依賴方向、名稱重複),據此選 3-5 個可疑區才讀內容深挖。可傳 path 參數縮限範圍。
- 判準來源分層:存在 `openspec/project.md` 時以其詞彙表作為模組邊界的權威判準;不存在時從 codebase 自行推斷 domain 語言,並在報告中明示該判準為推斷而非權威。
- 產出寫成 handoff 相容文檔至 `~/.agent/handoffs/<repo-slug>/<ID>.md`,含 `## Suggested skills` 與 `## Next steps` 兩段,使 `/pickup <ID>` 能直接接手執行選中的重構。
- 部署照 handoff 模式:Claude 端為 `commands/arch-review.md.tmpl`(`disable-model-invocation: true`),Codex 端為 `skills/arch-review/`,兩者共用 `.chezmoitemplates/skills/arch-review.md` 的 shared body。
- 一併修正 `home/dot_claude/commands/handoff.md.tmpl` description 中過期的路徑說法(`.claude/handoffs/` → `~/.agent/handoffs/`),使其與 body 及本次新增的 arch-review 說法一致。

非目標(明確排除):不掛進 dev-workflow / finish-branch 任何自動觸發點;不自動執行重構;不寫入 `openspec/project.md`。

## Capabilities

### New Capabilities
- `arch-review`: 手動觸發的整庫架構體檢——兩階段掃描紀律、判準來源分層、pickup 相容的產出契約,以及「只提候選不動手」的邊界。

### Modified Capabilities

無。`claude-config` 對 command 部署的要求是通則性的(新增/移除即自動部署),不列舉個別 command,故新增 arch-review 不改動其 requirement。`discipline-skills` 涵蓋的是六個模型可自行呼叫的紀律 skill;arch-review 是手動 command,不屬於該集合,亦不改動其 requirement。

## Impact

新增檔案:
- `home/.chezmoitemplates/skills/arch-review.md`(shared body)
- `home/dot_claude/commands/arch-review.md.tmpl`(Claude 手動 command)
- `home/dot_codex/skills/arch-review/SKILL.md.tmpl`(Codex skill wrapper)
- `openspec/specs/arch-review/spec.md`(archive 後由 sync 產生)

修改檔案:
- `home/dot_claude/commands/handoff.md.tmpl`(description 路徑修正)
- `README.md` / `docs/`(依專案規範記錄新能力)

相依:沿用既有的 handoff/pickup 檔案位置與 ID 約定(`~/.agent/handoffs/<repo-slug>/<ID>.md`)。`pickup` 本身不需修改——它的檔案解析是格式無關的,只依賴 `## Suggested skills` 與 `## Next steps` 兩段存在。
