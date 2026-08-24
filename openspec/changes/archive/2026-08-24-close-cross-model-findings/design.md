## Context

跨模型 review 的三條 Critical 與兩條 Split，全部經實測確認：

| # | 缺陷 | 誰抓到 | 為何前三輪沒抓到 |
|---|---|---|---|
| C1 | `case $?` 吃掉 `judge_segment` 的回傳值,置後被報成省略 | 對造 | 我的反向驗證只斷言**顏色**,沒斷言**訊息** |
| C2 | `claude-state.md:81` 的理由只對它取代掉的截斷食譜為真 | 對造 | 是我上一輪修正的直接後果,而我沒回頭讀那句理由 |
| C3 | Step 4 表格與程序遺漏「檔案存在但為空」 | 對造 | 收尾散文有寫,所以逐句讀時看起來完整 |
| S1 | 反斜線接續的呼叫在母體之外 | 我 | —— |
| S2 | design 宣稱的緩解(斷言檔案數)在實作裡不存在 | 我提出、對造加強 | 對造去比對了 archived design 與 code |

C1 的形狀值得單獨記:守衛的存在理由是分辨兩種靜默失敗,而它自己把其中一種報成另一種。
**這不是沒看仔細,是驗證問題本身漏了一維。**

## Goals / Non-Goals

**Goals:**

- 三條 Critical 修掉,且各自的驗證斷言到足以再次抓到它的粒度。
- 兩條 Split 依使用者裁決修掉。
- bare+worktree 的 registry 敘述回到與正典錨點一致。

**Non-Goals:**

- 不驗證豁免理由的內容（對造成功駁回,理由見 proposal）。
- 不做跨行變數流分析——本輪納入的只有反斜線接續,它是**一個語法上的呼叫**。
- 不動 `agent-reference-layout` spec:它規範 bare-worktree reference 的**檔案佈局**,
  不規範 registry 導出的內容,所以那三處是 body-only。

## Decisions

**D1：反向驗證從斷言顏色升級為斷言訊息。**
這是 C1 得以存活的唯一原因。單純修掉 `case $?` 而不動驗證,下一個同形狀的錯誤(例如
未來新增第三種 verdict)會再次以「兩種都紅所以通過」的方式溜過去。**修缺陷與修發現缺陷
的能力,是兩件事**,而本輪的全部教訓都落在後者。

**D2：邏輯行合併用 awk，行號取第一個實體行。**
其他選項是 `grep -A1` 後拼接(無法處理多層接續)或改用多行正則(POSIX grep 沒有)。
awk 一遍掃描即可,且能同時保留「這個邏輯行從第幾行開始」——診斷訊息必須指向使用者
真正要編輯的那一行,而那是接續的第一行,不是含 `--git-common-dir` 的那一行。

**D3：`files_seen` 從裝飾品變成斷言。**
上一輪的 design 寫了「搭配掃到的檔案數一起斷言」當作 floors 會寬鬆化的緩解,實作卻只
列印它。對造是**比對 design 與 code** 才發現的——這類落差不會被只讀 code 的 review 抓到,
也不會被只讀 design 的 review 抓到。既然要斷言,那次 `find` 的 stderr 也一併停止吞掉,
與主掃描的規則一致。

**D4：bare+worktree 的更正限定在「什麼真的需要手動」。**
實測:容器路徑為 `<repo>` 時,任一 worktree 內 `dirname(realpath(--path-format=absolute
--git-common-dir))` 得到 `<repo>`,即正確的容器 slug。所以:

- **slug** 在兩種架構下都由正典錨點正確導出——`worktree.md` 的「slug 會以 `-.bare` 結尾」
  與 `dev-workflow.md` 的「auto-derivation 是錯的」都只對「原始 common-dir 直接 slug 化」為真。
- **Main Repo Path** 確實分歧(`<repo>/main` 而非 `<repo>`),仍需查 registry。

更正到此為止,**不刪除 registry 查表的指引**:那條路徑仍然有真正的分歧要處理。

## Risks / Trade-offs

- **awk 前處理讓「行」不再等於檔案的行** → 接受,並在標頭寫明行號語意是邏輯行的起始行。
- **`files_seen` 的下限與 per-root floors 同樣會隨樹成長而相對寬鬆** → 接受。兩者都只在
  **縮減**時紅,方向正確;本輪不引入自動調整機制,因為那會讓「基準是什麼」本身變成隱式的。
- **D4 縮小了「bare+worktree 要手動」的範圍,可能有我沒想到的第三處分歧** → 以實測為準
  而非以記憶為準,且保留 registry 查表這條路,所以縮小範圍不會讓任何既有流程失去出路。

## Migration Plan

無。回退即 revert。

## Open Questions

無。
