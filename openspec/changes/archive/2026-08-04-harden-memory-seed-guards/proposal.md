## Why

`support-non-git-memory-seed` 剛把 `claude-memory-seed` 的適用範圍從 git repo 擴到所有專案
目錄。Review 找出三個實測確認的缺陷,全都因為那次擴大範圍而從「理論上存在」變成「日常會踩到」:

**① `$HOME` 護欄可被 symlink 繞過。** `refused()` 拿**已解析**的 `settings_root`
(`pwd -P` 的產物)去比對**未解析**的 `$HOME` 字串。實測:

```
HOME=$B/linkhome (symlink → $B/realhome),cwd 同之
→ 護欄未觸發,$B/realhome/.claude/settings.local.json 被建立
```

那正是 Claude 的 **user-level** 設定檔——design 裡唯一標為「會造成資料損害」的失敗模式。
現有測試會過,只因為這台機器的 `$HOME` 沒有 symlink 成分。macOS 的 `/home` 轉址、企業
NFS home、`HOME` 帶尾斜線都會踩到。`/tmp` 護欄有同一個病:macOS 的 `/tmp` 是
`/private/tmp` 的 symlink,過了 `pwd -P` 就不再匹配。

根因是同一個:**正規化只做了單邊**。上一輪 design D2 決定「兩個 anchor 都要 `cd -P`」,
卻沒把同一條規則套到拿來比對的基準值上。

**② 格式損毀的 `settings.local.json` 會被清成 0 bytes。** `>"$settings"` 先截斷才跑 `jq`;
jq 解析失敗吐不出東西,而 pipeline 的退出碼是 `tr` 的 0,`set -e` 看不見。實測輸入
`{"permissions":{"allow":["WebSearch"]},}` → `size=0`。這條路徑必然可達:`cur=""`(jq 讀不出
現值)正好落進「(re)write」分支,**格式壞掉的檔案正是這段程式碼決定要重寫的那一種**。

**③ 寫入失敗會讓 SessionStart hook 非零退出。** 實測唯讀目錄 → `exit=1` 加一行 `mkdir:
Permission denied`。`post-checkout` 那側包了 `|| true`,但 `modify_settings.json.sh.tmpl:113`
是裸呼叫。script 檔頭寫著「never blocks the caller」,現行程式碼並不保證這件事。

三者都反映同一個規範缺口:現行 spec 寫了「SHALL 安靜 exit 0」,卻沒有任何 scenario 釘住
**退出碼**本身,所以測試整套沒有一條斷言 `$?`——③ 和「`/` 護欄測試在非 root 環境恆真」
都是因此漏掉的。

## What Changes

- **護欄改為解析後對稱比對**:`$HOME` 與 `/tmp` 在啟動時各解析一次 physical path,與
  `settings_root` 做 resolved-to-resolved 比對。同時涵蓋 symlink、尾斜線,以及 macOS 的
  `/tmp` → `/private/tmp`。不硬編平台特例。
- **寫入改為 temp file + rename**:`jq` 成功才 `mv` 覆蓋目標,失敗則原檔完封不動。
- **明文保證絕不非零退出**:`apply` 的 dispatch 收尾為 `|| true`,使任何寫入失敗
  (唯讀掛載、磁碟滿、權限不足)都不會讓 hook 報錯。
- **spec 新增可驗證的退出碼與非破壞性 requirement**,補上現行只在散文裡承諾、卻無 scenario
  釘住的兩件事。
- **修正測試的三處空斷言**:比對兩次 `where` 輸出的斷言在 id 推導完全損壞時仍會綠
  (`where` 失敗印 `~/.claude/memory/-` 且 exit 0),改為與預期字面值比對;`/` 護欄改斷言
  退出碼;新增 `assert_rc` 並套用到所有護欄與遷移案例。
- **修正一條錯誤註解**:`try_migrate` 上方宣稱「`set -e` 下 AND list 的左手邊失敗會中斷」
  ——POSIX 明文豁免 AND-OR list 的非末項,實測亦然。這違反 `principles.md` 的「宣稱要嘛
  可驗證,要嘛不要寫」。
- **採納 review 的簡化**:`run_apply` 的 if/else 摺疊、`physical_of`+`slug` 併為 `id_of`、
  `new_sandbox` 直接發佈 `s`/`h`、移除 workflow 中與 harness 前置檢查重複的 step。

## Capabilities

### Modified Capabilities

- `claude-memory-seed`: 護欄比對方式(單邊 → 雙邊解析);新增「寫入為原子操作、失敗不損毀
  既有檔案」與「任何情況下 exit 0」兩條 requirement。

## Impact

- **修改檔案**:
  - `home/dot_local/bin/executable_claude-memory-seed` —— 護欄、原子寫入、dispatch 收尾、註解。
  - `tests/claude-memory-seed.test.sh` —— 修空斷言、加 `assert_rc`、補 symlink HOME /
    唯讀目錄 / 損毀 JSON / `/tmpfoo` 不該被擋 四類案例。
  - `.github/workflows/test-shell.yml` —— 移除重複 step。
  - `openspec/specs/claude-memory-seed/spec.md` —— 由 delta spec 驅動。
- **不變**:`<id>` 推導、既有 `~/.claude/memory/` 目錄命名、worktree 的 anchor 不對稱、
  遷移的 fold 比對邏輯。
- **blast radius**:護欄變嚴(涵蓋更多本來就該擋的路徑),寫入變安全(失敗不再損毀),
  退出碼恆為 0。沒有任何情境會因此**多**被種子。
