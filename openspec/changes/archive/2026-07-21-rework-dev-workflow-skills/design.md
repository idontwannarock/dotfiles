# Design: rework-dev-workflow-skills

## Context

三個觸發點:流程太重(brainstorming 的多重 approval gates)、維護成本(superpowers plugin + Codex symlink 腳本 + 設計文件改道補丁)、想收斂成 model-agnostic harness。研究 mattpocock/skills(2026-07-20 三路調查:repo 內容、本地生態盤點、episodic memory 設計史)後結論:與本系統互補的是其紀律 skills(grilling、tdd、diagnosing-bugs)與精簡哲學;其 issue-tracker 管線與 OpenSpec 脊椎同構衝突,不採用。完整討論見對話核可的 design note(2026-07-21)。

## Goals / Non-Goals

**Goals**
1. dev-workflow 的 superpowers 接線歸零,五個引用點全部由自家 skill 取代
2. 前端減重:多重 approval 的 brainstorming → 單一 stop-gate 的 grill
3. 補上 tdd(seam-based)與 diagnose(feedback-loop-first)紀律
4. 六個新 skill 全走 chezmoi shared-body + per-tool name-map,Claude / Codex / Antigravity 同體

**Non-Goals**
- 不改 OpenSpec artifact 格式、openspec-* skills、archive 機制
- 不動 code:review-*、git:*、handoff/pickup、workflow registry 機制本身
- 不採用 issue-tracker 管線(to-spec / to-tickets / triage / wayfinder)
- 不移除 superpowers plugin 本體(episodic-memory 糾纏未驗證,屬後續 change)
- 不修復 workflow-instructions spec 中與本次無關的既有 drift(推進模式等)

## Decisions

### D1:吸收改寫,不 vendor
- 選擇:需要的流程/紀律改寫為自家 shared-body skills;superpowers 與 mattpocock 都只當靈感來源。
- 替代:vendor mattpocock skills + 薄橋接;或只換前端的最小拼接。
- 理由:name-map 機制已是 model-agnostic harness,缺的只是內化;vendor 得為不需要的 tracker 管線養橋接層;最小拼接解決不了維護成本。MIT 授權與「easy to adapt」哲學支持吸收。

### D2:grill 取代 brainstorming
- 拿掉:9 步 checklist、逐段 approval、獨立 design doc、spec review gate、visual companion。
- 保留:一次一題、「確認共識才動工」單一 stop-gate。
- 新增:產出去向段(決策→design.md;動機範圍→proposal.md;行為要求→spec delta)、2-3 方案+推薦、「每題都要改變後續行為」的 no-op 提問禁令。
- 連帶:grill 不寫自己的文件 → user-system-prompt §8 文件改道機制退役。

### D3:tasks.md 切片慣例取代 writing-plans
- tracer-bullet 垂直切片、每片一個 fresh context window、依賴標 blocked by、大 refactor 用 expand–contract。
- 放 dev-workflow body(openspec-continue-change 為 CLI 生成,會被 `openspec update` 覆寫,不可寄放)。

### D4:tdd 接進 apply 階段
- seam 在 grill / design 階段決定並記錄於 design.md;red before green;垂直切片;refactoring 屬 review 階段;mock 只在系統邊界。細節放 references/(tests.md、mocking.md)。
- 無可測 seam 時明說跳過,由 verify-done 把關,不硬上。

### D5:diagnose 為 bug 進入點
- 硬 gate:沒有能穩定變紅的命令不准提假設;重現+最小化;3-5 個可否證假設;一次驗一個變數;regression test 只寫在正確 seam;根因 → proposal.md 的 Why。

### D6:機械三件內化
- verify-done:證據先於宣稱,~10 行。
- worktree:依 ARCH(normal / bare)建立 + 登記;隔離判斷仍在 `~/.agent/reference/dev-workflow-isolation.md`。
- finish-branch:雙架構原生內建 → §7 finishing override 段與 dispatch table 特例列刪除。

### D7:superpowers 兩階段處置
- 本次只解除接線;plugin 保留(episodic-memory 的 conversation archive 與 SessionStart hook 依賴 `~/.config/superpowers/`,未驗證獨立性前不移除)。

### D8:invocation 策略
- dev-workflow 保持 model-invocable(自動接住實作任務防漏 spec tracking;Small/Large/Skip 問句即人工 gate)。不採 mattpocock 的 orchestrator 一律 `disable-model-invocation`。
- grill / tdd / diagnose / finish-branch:model + user 皆可;verify-done / worktree:model。

## Risks / Trade-offs

- grill 無實戰履歷 → 本 change 即以新流程 dogfood 驗證
- 自寫 skill 收不到上游修正 → 接受,上游定位為靈感來源(D1 前提)
- Codex 端行為未驗證 → tasks 含 `chezmoi apply` 後雙工具實測
- episodic-memory 糾纏 → D7 兩階段隔離

## 附錄:核可的 skill body 草稿

### grill(全文)

```markdown
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
- 解法空間真的有分岔時,提出 2-3 個方案 + 取捨 + 你的推薦。
- 問到沒有新資訊為止,不是問到問題用完為止 — 但每一題都要
  改變後續行為;不改變行為的問題不要問。

## Stop-gate

在使用者明確確認「共識達成」之前,不得開始撰寫 openspec
artifacts、不得實作。這是本 skill 唯一的 gate。

## 產出去向

grill 不寫自己的文件。共識確認後,結論直接分流:
- 決策(選擇 / 替代方案 / 理由)→ design.md 的 ## Decisions
- 動機與範圍 → proposal.md 的 ## Why / ## What Changes
- 行為要求 → spec delta 的 ### Requirement / #### Scenario
```

### tdd(骨架)

```markdown
# TDD

只在預先同意的 seam 上測試。seam 在 grill / design 階段決定,
記錄在 design.md 的 Decisions — 實作中途不新開測試面。

## 循環

- Red before green:先看著測試失敗,才寫實作。
- 垂直切片:一個測試 → 一段實作 → 重複。不要橫切。
- 一次一片。前一片綠了才開下一片。
- Refactoring 不在循環內 — 那是 review 階段的事。

## 測試品質(詳見 references/)

- 好測試讀起來像規格,重構後仍存活。
- 反模式:綁實作細節的測試、恆真測試。
- Mock 只放在系統邊界。內部一律走真實介面。
```

### diagnose(骨架)

```markdown
# Diagnose

修 bug / 查效能退化的紀律。核心只有一句:
先建 feedback loop,沒有能穩定變紅的命令,不准提假設。

## Phases

1. 建 loop(優先序:失敗測試 → curl/CLI 重現 → headless
   browser → 拋棄式 harness);把 loop 收緊。
2. 重現 + 最小化:刪到每個剩下的元素都 load-bearing。
3. 提 3-5 個「可否證」假設,排序,秀給使用者。
4. 一次只驗一個變數;debug log 帶統一 tag。
5. 修復前先在正確的 seam 寫 regression test。
   沒有正確的 seam?這本身就是發現。
6. 清乾淨 debug 痕跡。
```

### tasks.md 切片慣例(dev-workflow body 內)

```markdown
tasks.md 撰寫慣例:
- 每個 task 是 tracer-bullet 垂直切片:窄但完整穿過所有層,
  不要按層橫切。
- 每片大小 = 一個 fresh context window 能完成。
- task 之間有依賴就標明(blocked by #N)。
- 大範圍 refactor 例外:expand–contract 排序,批次按 blast
  radius 分批。
```
