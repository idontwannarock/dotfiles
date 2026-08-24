## 1. C1 — 判定值被 `case $?` 吃掉

- [x] 1.1 `judge_segment` 呼叫後立即 `verdict=$?`，移除中介的 `case $?`。
      驗證：置後的輸入報「places --path-format after」，省略的輸入報「no --path-format=absolute」。
- [x] 1.2 反向驗證升級為斷言訊息而非僅斷言顏色。
      驗證：把 1.1 的修正暫時還原，該驗證變紅（不是只有顏色對就通過）。（blocked by #1.1）

## 2. S1 — 反斜線接續

- [x] 2.1 掃描前以 awk 併合反斜線接續行，行號取第一個實體行。
      驗證：`git rev-parse \` 換行 `  --git-common-dir` 變紅，且訊息指向起始行。
- [x] 2.2 標頭與〈WHAT THIS DOES NOT CHECK〉更新：行號語意為邏輯行起始行；
      跨行變數流仍在母體外。驗證：兩節與實作一致。（blocked by #2.1）

## 3. S2 / M2 — 檔案數

- [x] 3.1 `files_seen` 設下限並斷言；該次 `find` 停止吞 stderr。
      驗證：暫時把掃描根裡多個 `.md` 移走，檔案數下限觸發變紅；`chmod 000` 一個目錄亦變紅。
- [x] 3.2 上一輪 design 宣稱的緩解現在真的存在。
      驗證：`grep -n 'files_seen' tests/path-format-flag-order.test.sh` 出現於斷言而非僅列印。

## 4. C3 — 空的 findings 檔

- [x] 4.1 `review-cross-model.md` Step 4 的表格與編號程序納入「存在但為空」。
      驗證：表格四列與程序皆涵蓋，且與收尾散文的 "missing or empty" 一致。

## 5. C2 — bare+worktree 的 registry 敘述

- [x] 5.1 `claude-state.md`：更正理由——slug 由正典錨點正確導出，分歧在 Main Repo Path。
- [x] 5.2 `worktree.md`：刪去「slug 會以 `-.bare` 結尾」，改述為 Main Repo Path 需查 registry。
- [x] 5.3 `dev-workflow.md` 第 41、51 行：同上，不刪除 registry 查表指引。
      驗證：三處說法一致，且與 `repo-identity.md` 的 `dirname` 說明不相斥。（blocked by #5.1、#5.2）

## 6. 收尾

- [x] 6.1 `sh`／`bash`／`dash` 三種 interpreter 下全套測試綠，呼叫點數與 grep 實得一致。
      （blocked by #1.1、#2.1、#3.1）
