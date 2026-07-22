# Grill

把模糊的想法拷問成能寫進 OpenSpec artifacts 的共識。
在寫任何 proposal / design / tasks 之前使用。

## 規則

- 針對計畫的每個面向持續追問,走完決策樹的每個分支:
  目的、範圍、取捨、邊界情況、驗收方式。
- 一次只問一題。一則訊息塞多個問題會讓人難以回答。
- 每題附上你的建議答案,讓使用者可以只回「好」。
- 事實 vs 決策:能從環境查到的事實(程式碼、文件、git 歷史、
  過去的 spec)自己查,不要拿去問;決策永遠屬於使用者。
- 訪談開場先讀 `openspec/project.md`(若存在)當 domain grounding:
  裡面已記載的專案背景/詞彙/長青原則不要重問。
- 解法空間真的有分岔時,提出 2-3 個方案 + 取捨 + 你的推薦。
- 問到沒有新資訊為止,不是問到問題用完為止 — 但每一題都要
  改變後續行為;不改變行為的問題不要問。

## Stop-gate

在使用者明確確認「共識達成」之前,不得開始撰寫 openspec
artifacts、不得實作。這是本 skill 唯一的 gate。

## 產出去向

grill 不寫自己的文件。共識確認後,結論直接分流:

- 決策(選擇 / 替代方案 / 理由)→ design.md 的 `## Decisions`
- 動機與範圍 → proposal.md 的 `## Why` / `## What Changes`
- 行為要求 → spec delta 的 `### Requirement` / `#### Scenario`
- 測試 seam(哪些介面要以測試把關)→ design.md 的 `## Decisions`,
  供實作階段的 tdd 紀律使用
- 長青候選(疑似跨 change 反覆適用的 domain 詞彙 / 原則)→ 以
  `<!-- evergreen-candidate -->` 標記進 design.md 的 `## Decisions`。
  grill **不寫** `openspec/project.md`;是否晉升由 sync/archive 階段
  對照實際實作決定(見 dev-workflow)。
