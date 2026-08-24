## Why

跨模型 review（對造 codex）在同一分支上抓到三條同家族 review 全數漏掉的缺陷，外加兩條經
交換後成立的分歧。最尖銳的一條是守衛自己的 bug：`case $?` 吃掉判定值，於是**旗標置後被
報成「完全沒有旗標」**——而這支測試的存在理由正是分辨這兩種形狀。

三輪同家族 review 沒抓到它，因為它們與我共用同一個檢查問題：「該變紅嗎」。沒有人問過
「訊息指的是哪一種」。反向驗證只斷言顏色，於是兩種錯誤都變紅就通過了。

第二條是我自己的修正造成的：把 `claude-state.md` 的截斷食譜改成指向正典錨點後，留下了
只對截斷版為真的理由。正典錨點含 `dirname`，會剝掉 `.bare` 得到容器路徑——實測確認——
所以「derived slug does not match」與 `worktree.md` 的「slug 會以 `-.bare` 結尾」都是假的。
真正需要手動設定的只有 Main Repo Path。

## What Changes

**守衛的正確性**

- `judge_segment` 的回傳值立即存入變數，不再讓 `case $?` 吃掉——置後與省略各自報出正確診斷。
- 反向驗證改為同時斷言**顏色與訊息**，而不只是顏色。這是讓 C1 得以存活三輪的那個缺口。

**守衛的覆蓋**

- 掃描前先把反斜線接續行併成邏輯行（行號取第一個實體行），使跨行的單一 invocation
  進入母體。反斜線接續是**一個語法上的呼叫**，不是 design 非目標所排除的跨行變數流分析。
- 斷言 `files_seen` 的下限，並停止吞掉它那次 `find` 的 stderr。archived design 宣稱
  floors 的寬鬆化由「搭配掃到的檔案數一起斷言」緩解，而實作從未斷言它——這是 design
  與 code 的直接落差，由對造比對兩者後發現。

**文件的正確性**

- `review-cross-model.md` Step 4：表格與編號程序納入「檔案存在但為空」，與收尾散文和
  原始版本的 "missing or empty" 一致。
- `claude-state.md`、`worktree.md`、`dev-workflow.md`：更正 bare+worktree 的 registry 敘述。
  slug 在兩種架構下都由正典錨點正確導出；真正分歧的是 **Main Repo Path**（`<repo>/main`）。

**不含**：豁免理由的內容驗證。對造成功駁回——要求判斷理由是否充分需要任意啟發式，
與「顯式而非推論」的設計原則衝突，理由的把關屬 diff review。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `session-handoff`: 守衛的母體 SHALL 涵蓋反斜線接續的單一 invocation；`files_seen` SHALL
  被斷言而非僅列印；診斷訊息 SHALL 指認實際的錯誤形狀，且其驗證 SHALL 斷言訊息而非僅斷言失敗。
- `cross-model-review`: 收斂判定 SHALL 將「檔案存在但為空」與「檔案不存在」等同處置。
- `agent-reference-layout` 或 `workflow-concurrency`：若既有 spec 規範了 bare+worktree 的
  registry 導出則改之；否則僅改 body。

## Impact

- `tests/path-format-flag-order.test.sh`
- `home/.chezmoitemplates/skills/review-cross-model.md`、`worktree.md`、`dev-workflow.md`
- `home/dot_agent/reference/bare-worktree/claude-state.md`
- spec delta：`session-handoff`、`cross-model-review`
