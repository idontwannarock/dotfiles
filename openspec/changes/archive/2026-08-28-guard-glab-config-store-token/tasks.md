## 1. bash/zsh 守衛

- [x] 1.1 在 `home/.chezmoitemplates/shell-common/base` 的 `glab()` 內,於 `GITLAB_HOST`
  檢查之後、vault 讀取之前,加入 config store 掃描(global + repo-local),命中則印訊息
  並 `return 1`。
  - verify: `bash -c` 起一個載入該片段的 shell,分別以「有權杖 / 空值 / 純註解 /
    檔案不存在 / repo-local 有權杖」五種 fixture 跑過,前一種擋下且退出碼 1,後四種放行。

## 2. PowerShell 守衛(mirror)

- [x] 2.1 在 `home/Documents/exact__shared-profile.d/26-glab.ps1` 加入同位置、同訊息的守衛,
  以 `[Console]::Error.WriteLine` 輸出並設 `$global:LASTEXITCODE = 1`。
  - blocked by 1.1(訊息文字以 bash 版為正本)
  - verify: 訊息字串與 bash 版逐字比對(以 diff,不靠目視)。

- [x] 2.2 於 `tests/glab-wrapper.Tests.ps1` 補 regression:有權杖擋下、空值放行、
  註解不誤判、檔案不存在放行。
  - blocked by 2.1
  - verify: Pester 於 Windows 端跑過(WSL 無 pwsh 時記為未跑,不假稱通過)。

## 3. 文件

- [x] 3.1 `docs/gitlab-corp-access.md` 補一節:旁路(`auth login` / `config set`)、
  守衛訊息、清除指令、輪替要求;並把「config store 刻意不用」從敘述改為指向守衛。
  - blocked by 1.1
  - verify: 文件內的清除指令實際貼上可執行,且不含 corp FQDN。

## 4. 收尾驗證

- [x] 4.1 全 repo 搜尋 corp 網域字串,命中數為零。
- [x] 4.2 `chezmoi apply` 僅限本次子樹,確認 wrapper 於本機生效且 `glab api version` 正常。
  - blocked by 1.1, 3.1
