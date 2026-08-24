## Context

上一輪的守衛做對了一件事：它把「我 grep 過了」換成可執行的東西。但它的判定實作是三個
整行 `case` 比對，而它要守的檔案是散文與表格——這兩者的組合就是本輪的全部問題。

對抗式 review 複現的四條綠燈（皆已在隔離環境重跑確認）：

| 輸入 | 為何綠 |
|---|---|
| `` `git rev-parse --path-format=absolute --git-common-dir` then `git rev-parse --git-common-dir` `` | `${text%%--git-common-dir*}` 取**最短**前綴,第二個呼叫從未被看 |
| `` `git rev-parse --path-format=absolute --show-toplevel; git rev-parse --git-common-dir` `` | 前綴內確實有那個旗標——只是它綁在別的選項上 |
| `` \| `basename "$(git rev-parse --show-toplevel)"` \| `git rev-parse --git-common-dir` \| `` | form (b) 比對的是整行,同列另一格的慣用法赦免了整列 |
| 任何含 `<!-- flag-order:` 的行 | 豁免比對在 `rev-parse` 閘門之前,且不要求理由 |

第四條最難堪:守衛失敗時印的訊息就是
`<!-- flag-order: why this line is not a call site -->`。照著訊息貼上去,違反就消失了。

## Goals / Non-Goals

**Goals:**

- 判定的單位從「行」降到「invocation」——這一步同時解掉前三條。
- 讓母體縮減成為失敗,而不是靜默的成功。
- 讓守衛對自己母體的描述為真。

**Non-Goals:**

- 不把三支可執行腳本納入母體（見 D3）。
- 不做跨行的變數流分析。
- 不重寫 `skill-name-map-axis.test.sh`——它是另一族。

## Decisions

**D1：判定窗口 = 從最近的 `rev-parse` 到這一個 `--git-common-dir`。**
其他選項是「一行只准一個呼叫」（在滿是表格的文件裡不成立）或「解析 markdown 取出 code span」
（在 POSIX sh 裡是一整個 parser，且 parser 本身會有自己的靜默失敗）。取窗口是三者中唯一
同時便宜且正確的:旗標必須出現在它所影響的選項之前,而「之前」的邊界就是該次呼叫的起點。

**D2：豁免的三個收緊互相獨立，缺一都能被繞過。**
順序（移到 `rev-parse` 閘門之後）擋「一行同時有真呼叫與標記」；非空理由擋空標記；
錨定行尾擋「文件引用標記本身」。只做其中一項的話另外兩條路仍然開著。

**D3：三支腳本留在母體外，但這件事要寫在守衛裡而不是只寫在 change 裡。**
納入的話,它們的正規化發生在**後續行**（`localfiles:23`、`claude-memory-seed` 的 `physical()`),
同行判定必然對三支全部誤報——就是上一輪 D1 已經拒絕過的「第一天就紅」。真正的理由是它們
安全（已實測:git 跑 hook 的 cwd 恆為工作樹頂層,且所有 worktree 情境下 `--git-common-dir`
本來就回絕對路徑）,而不是它們難掃。**這句話要寫在 `WHAT THIS DOES NOT CHECK` 裡**:
該節存在的唯一理由就是「沒有標明母體的綠燈會被讀成『這一族已處理』」,而目前它漏掉了
可執行程式這一整塊。

**D4：母體下限逐根設定，不設全域。**
全域下限（現行的 `> 0`）只能分辨「全毀」與「其他」:14/16 消失仍然綠。逐根下限讓
「skills 樹整個掃不到」這件事本身變成紅燈,而那正是 `.md` 改名、`.chezmoiignore` 變更或
壞掉的 checkout 會造成的形狀。

**D5：兩條被推翻的 review 結論寫進 proposal，不只是口頭帶過。**
兩條都是信心 90 上下的 Critical,且兩條都源自同一個錯法——**在錯的佈局裡測**。
下一個人拿同樣的邏輯重推,會再得到同樣的錯誤結論;archive 裡留著實測數據才擋得住。

## Risks / Trade-offs

- **測試從 ~140 行長到 ~200 行** → 接受。增加的全部是判定精度與母體檢查,沒有新功能。
- **窗口取法對「一行內 `rev-parse` 出現在 `--git-common-dir` 之後」的畸形輸入無定義** →
  該情況不是合法呼叫,落回「找不到 `rev-parse` 前綴」而視為非呼叫點。這是保守方向:
  它讓守衛少管一行,不會讓它誤判為正確。
- **逐根下限是寫死的數字,會隨檔案增減而過期** → 接受並選下限而非等值:下限只在母體
  **縮減**時紅,新增檔案不會紅。過期的方向是變寬鬆,所以搭配「掃到的檔案數」一起斷言。

## Migration Plan

無。回退即 revert。

## Open Questions

無。
