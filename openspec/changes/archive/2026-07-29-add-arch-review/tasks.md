## 測試 seam 說明

本 change 的產出是 markdown skill body 與 chezmoi 模板,repo 現有測試設施僅有 `tests/corp-ssh-askpass.Tests.ps1`(Pester,針對 shell 腳本行為)。markdown 提示詞沒有可測的程式 seam,為它建測試設施不划算。

依 `discipline-skills` spec 的「無可測 seam」條款:**明說跳過 tdd**,正確性由 `verify-done` 以實際 `chezmoi apply` 輸出 + YAML parser 驗證 + 一次真實體檢跑測把關(見 Task 2)。

---

## 1. shared body 與雙工具 wrapper(垂直切片:一次打通到雙工具可用)

- [x] 1.1 撰寫 `home/.chezmoitemplates/skills/arch-review.md` shared body,涵蓋 spec 的五條 requirement:兩階段掃描(階段二上限 5 區)、判準分層與降級標示、pickup 相容產出(ID 約定 + 必含兩段)、只提候選不動手、報告需附證據
- [x] 1.2 建立 `home/dot_claude/commands/arch-review.md.tmpl`:frontmatter 含 `description` 與 `disable-model-invocation: true`,body 以 `{{ template "skills/arch-review.md" . }}` 引用
- [x] 1.3 建立 `home/dot_codex/skills/arch-review/SKILL.md.tmpl`:frontmatter 含 `name` 與**加引號的** `description`(Codex 嚴格 YAML),body 引用同一份 shared body
- [x] 1.4 `chezmoi apply` → 驗證 `~/.claude/commands/arch-review.md` 與 `~/.codex/skills/arch-review/SKILL.md` 皆存在且內容同源
- [x] 1.5 以真正的 YAML parser(非 grep)驗證 Codex 端 frontmatter 可解析

## 2. 真實跑測:產出與 pickup 相容性(blocked by #1)

- [x] 2.1 於一個**沒有** `project.md` 的 repo 實跑 `/arch-review`(建議 `chat_setting_api` 或 `ai-tools-list`),確認判準降級路徑運作且報告明示「推斷而非權威」
- [x] 2.2 確認報告寫在 `~/.agent/handoffs/<repo-slug>/<YYYY-MM-DD-HHMM>__arch-review.md`,且含 `## Suggested skills` 與 `## Next steps`
- [x] 2.3 於新 session 實跑 `/pickup <ID>`,確認能成功解析並接手 —— 這是 pickup 相容性的唯一有效驗證,不可用讀檔目視取代
      - 已完成。證據來源:**使用者於 chat_setting_api 新 session 實跑 `/pickup 2026-07-29-1610__arch-review` 並回報完成**(我未直接觀察該 session 輸出)。先前已機械驗證 slug 推導與三種解析法皆命中該檔。
      - 測試天花板:該次體檢結果為「無候選」,故 Next steps 為 no-op;驗證涵蓋解析與接手機制,未涵蓋「接手一個真正的重構任務」。
- [x] 2.4 確認全程未修改任何原始碼、未自動建立 OpenSpec change

## 3. handoff description 路徑修正(可與 #1 平行)

- [x] 3.1 修正 `home/dot_claude/commands/handoff.md.tmpl` 的 description:`.claude/handoffs/` → `~/.agent/handoffs/`,使其與 body 及 arch-review 說法一致
- [x] 3.2 `chezmoi apply` 後確認 `~/.claude/commands/handoff.md` 的 description 已更新

## 4. 文件(blocked by #1、#2)

- [x] 4.1 於 `docs/claude-code.md` 記錄 `/arch-review`:用途、兩階段掃描、判準分層、與 `review-*` 系列的分工(diff vs 整庫)
- [x] 4.2 於 `docs/codex-cli.md` 記錄 Codex 端的 `arch-review` skill
- [x] 4.3 依 Task 2 的實跑結果補上一段「何時該跑」的使用建議(里程碑 / 數個 change 累積後,而非每條 branch)
- [x] 4.4 檢查 `README.md` 的工具/能力表格是否需要同步(參照 PR #37 的表格修正慣例)
      - 查證結論:**不需要**。README 該表格為目錄層級(`~/.claude/commands/`、`~/.codex/skills/`),不列個別 command/skill,arch-review 已被涵蓋。
