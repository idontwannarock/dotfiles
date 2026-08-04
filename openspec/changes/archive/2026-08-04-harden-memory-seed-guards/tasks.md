## 1. 先讓現有測試能抓到這三個缺陷

三個缺陷都是「現行測試全綠但程式碼有洞」,所以第一步是修測試,不是修程式。修完應該看到
**紅燈**——看不到紅燈就表示測試還是抓不到,那才是真正要解決的問題。

- [x] 1.1 新增 `assert_rc <expected> <actual> <msg>`,並讓 `run_apply` / `run_where` 能取得
      退出碼與 stderr(目前兩者都把 stderr 丟進 `/dev/null` 且不看 `$?`)。
- [x] 1.2 修三處恆真斷言:`worktree 共享 id`、`symlinked project dir`、
      `symlinked non-git project dir` 目前拿兩次 `where` 輸出互比,而 `where` 解析失敗時印
      `~/.claude/memory/-` 並 exit 0。改為與測試自行算出的預期值比對。
      → verify:刻意讓 `repo_id` 回傳空值,這三條必須變紅。
- [x] 1.3 修 `/` 護欄斷言:改為斷言 exit 0 且 stderr 靜默。
      → verify:註解掉 `refused` 的 `/` 分支,該條必須變紅。

## 2. 護欄改為雙邊解析

- [x] 2.1 新增紅燈測試:`$HOME` 為 symlink 時護欄仍須擋下;`/tmpfoo` 這種前綴相同但不在
      `/tmp/` 之下的路徑**仍須**被種子(負向測試,防止護欄變得過度寬泛)。
- [x] 2.2 啟動時解析 `home_p` / `tmp_p`,`refused()` 改用兩者比對;解析失敗退回原字串
      (失敗方向為「多擋」)。
      → verify:2.1 轉綠,既有 30 條維持綠。

## 3. 寫入改為原子操作

- [x] 3.1 新增紅燈測試:既有 `settings.local.json` 為非法 JSON 時,執行 apply 後檔案位元組
      數不變;成功寫入後目錄下無暫存檔殘骸。
- [x] 3.2 改為 temp file + `[ -s ]` 檢查 + `mv`。`[ -s ]` 是必要的——`printf | jq | tr` 的
      退出碼取自 `tr`,`jq` 的失敗不會反映在退出碼上。
      → verify:3.1 轉綠。

## 4. 保證 exit 0

- [x] 4.1 新增紅燈測試:唯讀專案目錄下執行 apply,退出碼須為 0 且 stderr 有訊息。
- [x] 4.2 `apply) do_apply || true ;;`。收在唯一出口,而非逐個寫入點包防護。
      → verify:4.1 轉綠。

## 5. 註解與簡化

- [x] 5.1 修正 `try_migrate` 上方那條錯誤的 `set -e` 說明(POSIX 豁免 AND-OR list 的非末項;
      實測 `sh -c 'set -e; false && echo x; echo 存活'` 會印「存活」)。改寫成實際成立的理由。
- [x] 5.2 採納 review 的簡化:`run_apply` 的 if/else 摺疊(`:-` 使 unset 與空值等價)、
      `physical_of`+`slug` 併為 `id_of`、`new_sandbox` 直接發佈 `s`/`h`、`amd` 移除無效的
      `|| printf ''`、workflow 移除與 harness FATAL gate 重複的 prerequisites step、
      `find_claude_memory` 的 `${_p}memory` 去掉雙斜線。
      → verify:全套測試在 `sh` 與 `bash` 下皆綠。

## 6. spec 與實機驗證

- [x] 6.1 `openspec validate harden-memory-seed-guards` 通過;確認新增的兩條 requirement
      與 MODIFIED 護欄的每個 scenario 都有對應測試。
- [x] 6.2 `chezmoi apply` **僅** `~/.local/bin/claude-memory-seed`。
- [x] 6.3 實機重跑 review 期間確認缺陷的三個情境(symlink HOME、損毀 JSON、唯讀目錄),
      三者皆須安全。
      → verify:這三個情境在 review 時都是實測失敗的,必須實測轉為通過才算數。
