## Context

三個缺陷都在 `support-non-git-memory-seed` ship 的同一支 script 裡,由 review 發現並在本機
實測確認。它們不是新功能的 bug,而是**既有寫法在適用範圍擴大後暴露出來的洞**——非 git gate
還在時,這些路徑要嘛不可達,要嘛只影響 git repo。

約束不變:POSIX `sh`、`set -eu`、跨 Windows/macOS/Linux、由 hook 呼叫故絕不可阻斷 caller。

## Goals / Non-Goals

**Goals:**

- 護欄對 symlink、尾斜線、平台 symlink(`/tmp` → `/private/tmp`)一律成立。
- 寫入為原子操作:失敗時既有檔案完封不動。
- 任何情況下 `apply` 都 exit 0。
- 讓上述三件事各自有 spec scenario 與可失敗的測試釘住。

**Non-Goals:**

- 不改 `<id>` 推導、不改既有目錄命名、不改 worktree 的 anchor 不對稱、不改 fold 比對。
- 不處理 `TMPDIR`(macOS 的 `/var/folders/...`)。`/tmp` 護欄的目的是擋拋棄式 checkout,
  而 `TMPDIR` 下的路徑目前沒有實際樣本;無樣本可驗的規則不寫進來(與上一輪拒絕硬編
  Claude slug 規則同一個判準)。

## Decisions

### D1. 正規化必須雙邊,不是單邊

<!-- evergreen-candidate -->
上一輪 D2 決定「anchor 一律過 `cd -P`」,但只套用在**被檢查的值**上;拿來比對的基準
(`$HOME`、字面 `/tmp`)仍是原始字串。結果是護欄在 `pwd -P` 之後比對 `pwd -P` 之前的東西,
symlink 一介入就永遠不相等。

改為啟動時各解析一次:

```sh
home_p=$(physical "${HOME:-}")  || home_p=${HOME:-}
tmp_p=$(physical /tmp)          || tmp_p=/tmp
```

`refused()` 用 `home_p` / `tmp_p` 比對。`|| ` fallback 讓解析失敗(`$HOME` 不存在、無 `/tmp`)
退回原字串,而不是讓護欄整個消失——**護欄的失敗方向必須是「多擋」而非「少擋」**。

macOS 的 `/private/tmp` 因此自動涵蓋,不需要硬編平台特例:`physical /tmp` 在該平台就會回
`/private/tmp`。

**Alternative considered**:硬編 `case ... /private/tmp*)` —— 拒絕,那是為一個平台補一條
規則,下一個平台再補一條;解析基準值是規則無關的做法。

### D2. 寫入改 temp file + rename

`>"$settings"` 在 `jq` 執行**之前**就把目標截斷了,所以 jq 失敗 = 檔案歸零。改為:

```sh
tmp="$settings.tmp.$$"
if printf '%s' "$input" | jq ... | tr -d '\r' >"$tmp" && [ -s "$tmp" ]; then
    mv "$tmp" "$settings"
else
    rm -f "$tmp"; return 0
fi
```

`[ -s "$tmp" ]` 是關鍵:`jq` 失敗時 pipeline 的退出碼是 `tr` 的 0,單看退出碼抓不到,必須
額外檢查產物非空。`mv` 同目錄內是 rename,原子。

**Alternative considered**:先驗 `jq -e . "$settings"` 再決定要不要寫 —— 多跑一次 jq,而且
仍需處理「驗過之後、寫入之前」的空窗;temp+rename 一步到位。

### D3. dispatch 收尾 `|| true`,而非在每個寫入點加防護

失敗點不只 `mkdir`:`jq` 不在、磁碟滿、`mv` 跨檔案系統、目標目錄唯讀都會讓 script 非零退出。
逐點包 `|| true` 既囉唆又必然漏掉新加的路徑。改在唯一的出口收尾:

```sh
apply) do_apply || true ;;
```

script 的職責是「盡力種子」,不是「回報種子成功與否」;呼叫端(SessionStart hook)也沒有
消費退出碼的機制。stderr 的診斷訊息保留。

**Alternative considered**:讓 `modify_settings.json.sh.tmpl` 的 hook command 加 `|| true`
—— 拒絕。那把不變量放在呼叫端,而呼叫端有兩個(hook + post-checkout),且 script 檔頭已經
承諾了這件事;不變量該由承諾它的那一方保證。

### D4. 測試新增 `assert_rc`,並修掉三處恆真斷言

<!-- evergreen-candidate -->
現行三條斷言拿兩次 `where` 的輸出互比:

```sh
assert_eq "$(run_where "$repo" "$h")" "$(run_where "$wt" "$h")"
```

`where` 在解析失敗時印 `~/.claude/memory/-` 並 exit 0(實測 `od -c` 確認),所以 id 推導**完全
損壞**時兩邊仍然相等,測試照樣綠。改為與預期字面值比對——同一份測試裡的
`bare+worktree layout` 案例本來就是這樣寫的,照抄即可。

同理,`/` 護欄斷言 `assert_absent /.claude/settings.local.json` 在非 root 環境恆真(GitHub
runner 以非特權 `runner` 身分執行),把護欄整段刪掉它還是綠。改為斷言退出碼與 stderr 靜默。

判準:**斷言的兩邊不能都由受測程式產生**;至少一邊要是測試自己算出來的預期值。

## Risks / Trade-offs

**[R1] 護欄變嚴可能擋掉本來會被種子的目錄** → 只在 `$HOME` / `/tmp` 經由 symlink 抵達時
發生,而那些情境本來就該被擋——是修正而非退步。反向風險(不該擋的被擋)由新增的
`/tmpfoo` 負向測試釘住:前綴相同但不在 `/tmp/` 之下的路徑仍須被種子。

**[R2] `$settings.tmp.$$` 可能與既有檔案撞名** → 同目錄、含 PID、寫前不讀取,撞名的唯一
後果是覆蓋一個本來就是殘骸的 `.tmp.<pid>` 檔。不引入 `mktemp`(POSIX 無此命令,且需要處理
它在不同平台的參數差異)。

**[R3] `|| true` 會遮蔽真正的程式錯誤** → 接受。stderr 的訊息仍然完整輸出,診斷資訊沒有
遺失;而讓 hook 因為種子失敗而報錯,對使用者的傷害大於一個安靜的失敗。

## Migration Plan

1. 改 script → `chezmoi apply` **僅** `~/.local/bin/claude-memory-seed`。
2. 實機重跑 review 期間那三個確認缺陷的情境(symlink HOME、損毀 JSON、唯讀目錄),
   確認三者現在都安全。
3. 全套測試在 `sh` 與 `bash` 下各跑一次。

**Rollback**:純函式性改動,還原檔案即可;沒有任何狀態遷移。

## Open Questions

無。
