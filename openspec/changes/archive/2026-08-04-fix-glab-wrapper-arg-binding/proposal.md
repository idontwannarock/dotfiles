## Why

`Documents/exact__shared-profile.d/26-glab.ps1` 宣稱自己是 `.chezmoitemplates/shell-common/base`
裡 `glab()` 的 mirror,「兩個錯誤字串刻意保持一致」。實測三處不成立:

1. **參數繫結吃掉 glab 的短旗標。** `[CmdletBinding()]` + `ValueFromRemainingArguments`
   的組合會先做具名參數繫結、且 common parameter 支援前綴比對。實測:
   `glab mr create -d desc` → glab 收到 `mr create desc`(`-d` 綁到 `-Debug` 後消失,
   description 淪為位置參數);`glab mr list -R owner/repo` → **直接報錯**,命令根本
   沒送出去。`-R/--repo` 與 `-d/--description` 都是 glab 的日常旗標。bash 版用 `"$@"`,
   沒有這個問題。
2. **錯誤字串其實不一致。** `Write-Error` 會再前綴一次 function 名,實際輸出是
   `glab: glab: GITLAB_HOST 未設定…`;bash 版是 `printf >&2`,只有一次。順帶一提,
   `Write-Error` 走 error stream 而 bash 走 stderr,而且兩個守衛路徑 bash `return 1`、
   pwsh 卻讓 `$LASTEXITCODE` 停在上一個命令的值,腳本讀到的是過期的成功。
3. **檔頭把 token 來源寫錯。** 檔頭寫「Token source: gopass gitlab/corp-token
   (shared vault with WSL `pass`)」,但實測是兩個各自獨立的 store —— WSL
   `/home/howardwang/.password-store`、Windows `C:\Users\user\.password-store`,
   各存一份 `gitlab/corp-token`。`docs/gitlab-corp-access.md` 列的兩道獨立 insert 才是對的。
   誤導之處在於會讓人以為 Windows 那步可以跳過,而那步跳過的症狀是 401 —— 一個指向
   token 的錯誤,成因卻在別處,正是這支 wrapper 當初要消滅的那種錯誤。

另有一項防禦性缺口:檔案含非 ASCII 卻沒有 UTF-8 BOM。`Documents/_shared-profile.d/*.ps1`
同時被 PS 5.1 與 PS 7 的 profile loader dot-source,而 PS 5.1 的 parser 對無 BOM 檔案
會退回系統 ANSI codepage(本機 cp950),中文序列 mojibake 後可能吃掉引號而在無關行報錯。

## What Changes

- 移除 `[CmdletBinding()]` 與 `param(ValueFromRemainingArguments)`,改用裸 function 的
  `$args`(不做任何繫結),與 `96-chezmoi-guard.ps1` 同形。
- 兩個守衛路徑改用 `[Console]::Error.WriteLine`,並把 `$LASTEXITCODE` 設為 1,使錯誤
  字串、輸出串流與退出碼三者都真的與 bash 版一致。
- 更正檔頭的 token 來源敘述,指向 `docs/gitlab-corp-access.md` 的兩道獨立 insert。
- 補 UTF-8 BOM。
- 新增 `tests/glab-wrapper.Tests.ps1`,把 `-d`/`-R` 這兩個實測會壞的形態釘成 regression。

## Capabilities

### New Capabilities
<!-- 無。 -->

### Modified Capabilities
- `corp-gitlab-access`: wrapper 對參數的處理與錯誤輸出從「宣稱一致」變成「可驗證一致」。

## Impact

- 修改:`home/Documents/exact__shared-profile.d/26-glab.ps1`
- 新增:`tests/glab-wrapper.Tests.ps1`
- 不動:bash/zsh 版的 `glab()`(本來就正確)、`docs/gitlab-corp-access.md`(本來就正確)
