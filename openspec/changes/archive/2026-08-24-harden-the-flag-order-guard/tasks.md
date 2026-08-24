## 1. 判定精度

- [x] 1.1 判定窗口由整行改為每個 invocation：對行內每個 `--git-common-dir`，取「最近的前一個
      `rev-parse` 至該處」為窗口；找不到前置 `rev-parse` 者視為非呼叫點。
      驗證：design 表列的四條輸入，前三條各自變紅。
- [x] 1.2 走完行內所有出現處，不再只判第一個。
      驗證：`` `git rev-parse --path-format=absolute --git-common-dir` then `git rev-parse --git-common-dir` ``
      這一行變紅，且訊息指出的是第二個呼叫。（blocked by #1.1）
- [x] 1.3 form (b) 的慣用法比對限縮在窗口內，不再是整行子字串。
      驗證：同列表格另一格含 `basename "$(git …)"` 時，本格的破呼叫仍變紅。（blocked by #1.1）

## 2. 豁免收緊

- [x] 2.1 豁免比對移到 `rev-parse` 閘門之後；要求非空理由與收尾 `-->`；錨定行尾。
      驗證：三條各自變紅——(a) 同行有真呼叫加標記、(b) `<!-- flag-order: -->` 空理由、
      (c) 句中引用標記的文件行。
- [x] 2.2 守衛印出的修正建議不得是可直接貼上就解除守衛的字串。
      驗證：把失敗訊息裡的建議字串原樣貼到一個破呼叫行尾，該行仍變紅（因為它不在行尾／無理由）。
      （blocked by #2.1）

## 3. 母體完整性

- [x] 3.1 不再 `2>/dev/null`：`find`／`grep` 的 stderr 有內容即 fail；grep exit code > 1 視為錯誤。
      驗證：`chmod 000` 一個含破呼叫的檔案後測試變紅；還原後回綠。
- [x] 3.2 母體下限改為逐根：每個掃描根各設呼叫點下限，並斷言掃到的檔案數。
      驗證：暫時把某個掃描根的 `.md` 改名成 `.md.bak`，測試變紅；還原後回綠。
- [x] 3.3 `-name` 涵蓋 `*.md.tmpl`。
      驗證：造一個含破呼叫的 `.md.tmpl` 於掃描根下，測試變紅；刪除後回綠。
- [x] 3.4 掃描根抽成單一變數，只寫一次。
      驗證：`grep -c 'chezmoitemplates/skills' tests/path-format-flag-order.test.sh` 為 1。

## 4. 自述為真

- [x] 4.1 修正標頭矛盾的驗屍報告：`pickup.md` 是**省略**，它就是那五支之一。
      驗證：標頭裡不再同時出現「五支都正確」與「pickup 省略」。
- [x] 4.2 修正 form (b) 的站點數（範圍內為四），並把三支腳本改述為第三種安全形式且不在母體內。
      驗證：所述數字與 `grep` 實得一致。
- [x] 4.3 〈WHAT THIS DOES NOT CHECK〉明寫可執行程式不在母體內及其理由（同行判定必誤報；
      三支已實測安全）。驗證：該節提到 `home/dot_local/bin/` 與 `home/dot_config/git/hooks/`。

## 5. 文件

- [x] 5.1 `review-cross-model.md` Step 5 限定「confirm as in Step 4」的承接範圍，並釘死
      該情境的退化理由為 `rebuttal exchange incomplete`。
      驗證：Degrading 表與 Step 5 對 rebuttal 檔缺失只給一個理由。
- [x] 5.2 `coordinate.md:1101` 的標記移進最後一格。
      驗證：該列的 cell 數與表頭一致。
- [x] 5.3 掃描根缺失時的提早 exit 走與其他失敗路徑相同的總結輸出。
      驗證：所有失敗路徑都印 `%d failure(s)`。

## 6. 收尾

- [x] 6.1 `sh` 與 `bash` 下三支測試全綠，且新守衛回報的呼叫點數與 `grep` 實得一致。
      （blocked by #1.1、#2.1、#3.1）
