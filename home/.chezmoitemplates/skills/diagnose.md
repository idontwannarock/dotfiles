# Diagnose

修 bug / 查效能退化的紀律。核心只有一句:
先建 feedback loop — 沒有能穩定變紅的命令,不准提假設。

## Phases

1. **建 loop**:找一個能重現失敗的命令。優先序:失敗測試 →
   curl / CLI 重現 → headless browser → 拋棄式 harness。
   把 loop 收緊:2 秒確定性 loop 遠勝 30 秒 flaky loop。
2. **重現 + 最小化**:刪到每個剩下的元素都 load-bearing。
3. **假設**:提 3-5 個「可否證」假設,依可能性排序,秀給使用者。
4. **驗證**:一次只驗一個變數;debug log 帶統一 tag
   (如 `[DEBUG-xxxx]`)方便事後清除。
5. **修復**:先在正確的 seam 寫 regression test,看它變紅,
   才動手修。沒有正確的 seam?這本身就是發現 — 回報,不硬塞。
6. **收尾**:清乾淨所有 debug 痕跡(grep tag 驗證)。

## 與流程的銜接

診斷出的根因直接成為該 change proposal.md 的 `## Why` —
change 的動機由證據支撐,不是「疑似」。診斷完成後回到
workflow 選擇(通常 Small)。
