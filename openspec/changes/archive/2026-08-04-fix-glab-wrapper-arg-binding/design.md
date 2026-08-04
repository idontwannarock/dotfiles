## Context

`26-glab.ps1` 的檔頭寫著它是 `.chezmoitemplates/shell-common/base` 中 `glab()` 的 mirror,
「兩個錯誤字串刻意保持一致」。這句宣稱在三個層面不成立,而三者都是靜默的:參數被吃掉不會
報錯(只是跑了別的命令)、錯誤訊息多一層前綴不會被察覺(訊息還是看得懂)、檔頭的 vault
敘述錯了也不會有任何機制去對照。

實測(pwsh 7,以同形 param block 的探針函式):

| 使用者輸入 | glab 實際收到 |
|---|---|
| `mr create -d desc` | `mr create desc` —— `-d` 綁到 `-Debug` 後消失 |
| `mr list -R owner/repo` | 繫結失敗,命令未送出 |
| `api -F k=v`、`-a`、`-t`、`-b` | 正常 |

vault 敘述的實測:WSL `/home/howardwang/.password-store` 與 Windows
`C:\Users\user\.password-store` 是兩個獨立的 store,各存一份 `gitlab/corp-token`。
`docs/gitlab-corp-access.md` 列的兩道獨立 insert 是對的,檔頭的「shared vault」是錯的。

## Goals / Non-Goals

**Goals:**

- 讓 `glab` 的每個參數原封不動送達,含與 PowerShell common parameter 撞名的短旗標。
- 讓「兩邊一致」這句宣稱變成可驗證的:字串、串流、退出碼三者都一致。
- 修正檔頭的 token 來源敘述,並補上 BOM。

**Non-Goals:**

- 不動 bash/zsh 版的 `glab()` —— 它用 `"$@"`,本來就正確。
- 不動 `docs/gitlab-corp-access.md` —— 它本來就正確,錯的是檔頭。
- 不改 wrapper 的憑證解析順序或 host 檢查邏輯。

## Decisions

### D1: 用裸 function 的 `$args`,不用 `[CmdletBinding()]` + `ValueFromRemainingArguments`

`ValueFromRemainingArguments` 收的是**具名繫結之後剩下的**參數,而 common parameter
支援前綴比對,所以任何與 `Verbose`/`Debug`/`ErrorAction`… 撞前綴的短旗標都會先被拿走。
裸 function 的 `$args` 不經過繫結器,是 PowerShell 裡唯一真正等價於 bash `"$@"` 的形狀。

代價:失去 `[CmdletBinding()]` 帶來的 `-Verbose`/`-Debug` 支援。這對 pass-through
wrapper 是收益而非代價 —— 那些旗標本來就該屬於被包的 CLI。

`96-chezmoi-guard.ps1` 已是此形狀,兩支 wrapper 收斂到同一個寫法。

### D2: 錯誤路徑用 `[Console]::Error.WriteLine` 並顯式設 `$LASTEXITCODE`

PowerShell 沒有「乾淨單行 + 可被 `2>` 攔截」的錯誤輸出,只能二選一:

| 機制 | `2>` / `2>&1` 攔得到 | OS 層 stderr | 單行乾淨 | `$?` / `$Error` |
|---|---|---|---|---|
| `Write-Error` | 是 | 是 | **否** —— 兩個版本的 PS 都渲染成引用原始碼行的多行區塊,且再前綴一次 function 名 | 有 |
| `[Console]::Error` | **否** | 是 | 是 | 無 |
| `Write-Host` | 否(要 `6>`) | 是 | 是 | 無 |

選 `[Console]::Error`:spec 的措辭是「於 stderr 印出」,而它字面上就是 process 的
stderr;訊息的讀者是人,單行且與 bash 逐字相同比可重導更重要。代價寫進註解,避免下一個
人把它「修」回 `Write-Error`。

退出碼是 bash `return 1` 的對應物 —— pwsh 版原本讓 `$LASTEXITCODE` 停在上一個命令的值,
讀到的是過期的成功。`binary not on PATH` 取 127(command-not-found 慣例,與
`96-chezmoi-guard.ps1` 一致),另外兩個守衛取 1。

<!-- evergreen-candidate -->
「兩邊刻意一致」這種宣稱要嘛可驗證,要嘛不要寫。字串一致但串流與退出碼不一致,
讀者會按宣稱去信任它,而落差只在出事時才顯現。

### D3: 補 BOM,而非改 profile loader

PS 5.1 的 parser 在讀檔時就決定編碼,晚於它的任何 `chcp` / `[Console]::OutputEncoding`
設定都影響不到。BOM 是唯一在正確時機生效的手段,且 PS 7 對 BOM 透明,加了無副作用。

## Risks / Trade-offs

- **[`$args` 在 advanced function 語意下不可用]** → 本函式不需要 `[CmdletBinding()]`
  的任何能力(無 pipeline 輸入、無 `ShouldProcess`),移除後 `$args` 即可用。
- **[測試需要 mock glab,而 mock 無法覆蓋 glab 真實的旗標語意]** → 測試斷言的是
  「wrapper 轉交了什麼」,不是「glab 怎麼解讀」。前者正是本次的缺陷所在,後者是 glab 的事。
  另以真實 `glab.exe` 跑過 `-R` 與 `-d` 兩個形態,確認修法不是只滿足 mock。
- **[移除 `[CmdletBinding()]` 的連帶影響大於「失去 -Verbose/-Debug」]** → 守衛拒絕時
  `$?` 維持 `True`、`$Error` 不再累積、`try { glab … } catch` 不再觸發,且 `-ErrorAction`
  不再是 common parameter 而是原樣轉交給 `glab`。對這支 wrapper 都是可接受的:它的
  失敗訊號是退出碼(與 bash 版一致),而 `-ErrorAction` 本來就該屬於被包的 CLI。

## Open Questions

- 無。
