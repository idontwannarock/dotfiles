## 1. 豁免綁 token（F2/F3）

- [x] 1.1 `carrier-positional-reference.test.sh`:`judge_line` 改為「該行每一個命中的 token 都要在被豁免集合裡」。標記格式 `<!-- positional-ref: <token>: <理由> -->`;理由拒收純空白;比對前去尾隨空白;標記之後若有別的 HTML 註解則不算標記
  - 驗:self_check 補四個 fixture——混合行(合法豁免＋真違規)判 1、純空白理由判 1、尾隨空白仍判 2、標記後另有註解判 1
- [x] 1.2 改寫樹裡既有的 6 個 `positional-ref` 標記為新格式
  - blocked by 1.1（1.1 一落地它們全部失效，轉紅就是驗收）

## 2. 字元集補齊（F10）

- [x] 2.1 加 Arabic 數字、超過十的中文數、大小寫不敏感;英文側加 `carrier`／`slot`,並涵蓋 `first`〜`tenth`
  - 驗:`第3格`、`第11項`、`the FIRST kind`、`the third carrier` 四個 fixture 全部判 1

## 3. 同步守衛（F4/F5）

- [x] 3.1 觸發字元改探帶反引號的形狀（`` `$` ``／`` `!` ``），不再裸搜單一位元組
  - 驗:轉紅實證——移除一側的 `` `!` ``、同時在同窗散文放一個裸驚嘆號 → 必須轉紅（舊實作在此為綠）
- [x] 3.2 signature 納入規則指名的來源與目的載體（中英各自正規化）
  - 驗:轉紅實證——單側把「升為檔案＋通知格」改成「檔案格」 → 必須轉紅（舊實作在此為綠）
- [x] 3.3 `self_check` 補一個比對路徑的斷言（不只驗 `extract()`）

## 4. fixture 層（F7）

- [x] 4.1 `carrier-positional-reference.test.sh` 加 `message_check`：fixture 含違規／豁免／乾淨三行
  - 驗:斷言違規檔被點名、**豁免那行不被點名**、建議文字出現
  - 驗:變異實證——把 verdict 1 改判成豁免 → `message_check` 必須轉紅
  - blocked by 1.1

## 5. xref 豁免綁位置（F9）

- [x] 5.1 豁免表改為 `檔案<TAB>名字<TAB>理由`，`is_exempt` 比對兩欄
  - 驗:把 `〈資源池〉` 加到 `dev-workflow.md` → 必須轉紅（舊實作為綠）

## 6. 收束不一致與假宣稱（F6/F11/F13/F14/F15/F16/F17/F18/F19）

- [x] 6.1 `spec.md:443` 第三列的敘述與 `:445` 收束成一句
- [x] 6.2 移除 `grep_status` 那段永不觸發的檢查（F6）
- [x] 6.3 `floor_refs` 由 28 提到實測值之下（F11）；修正 xref 檔頭「33 個引用」（F16）
- [x] 6.4 修正 `carrier-positional-reference.test.sh` 檔頭「豁免只有三條」（F15）——**改成不寫計數**，計數會腐爛，這條發現自己就示範過一次
- [x] 6.5 修正 `test-shell.yml` 那段把三支測試都說成宣告了兩棵樹的註解（F13）
- [x] 6.6 修正 xref 檔頭關於 `[^〉]` 在 C locale 行為的敘述（F17）——它只卡在 `E3/80/89` 三個位元組
- [x] 6.7 `coordinate.md:787` 的「已記在 backlog」改為指向 `tests/carrier-contract-sync.test.sh`；`dev-workflow.md` 線側也要指得到（F18）
- [x] 6.8 CI 改為 `"$shell" "$t"`，保留 `SEED_SH`（F19）

## 7. 收斂

- [x] 7.1 `openspec validate --all` 全過
- [x] 7.2 六支測試在 `sh` 與 `bash` 下皆綠，**離開碼逐支立刻接住**
  - ⚠️ 上一輪就是在這一步用 `printf ... $?` 讀到 `$(basename ...)` 的離開碼，得到假綠燈
  - blocked by 1.2, 2.1, 3.3, 4.1, 5.1, 6.8
