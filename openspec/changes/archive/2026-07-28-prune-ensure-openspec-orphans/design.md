## Context

三個問題都在 `retire-superpowers-plugin-cleanup` 的稽核與 code review 中浮現,當時判定超出該 change 範圍而只回報未修。

**孤兒 command 的實際行為**(已於本機驗證):

```
$ command -v ensure-openspec.sh
/mnt/c/Users/howard.wang/.local/bin/ensure-openspec.sh   # Apr 1, 774 bytes
```

`~/.local/bin` 有**兩份**四月舊副本,內容相同:

| 路徑 | 權限 | PATH 位置 |
|---|---|---|
| `~/.local/bin/ensure-openspec.sh` | `-rw-r--r--` | 1 |
| `/mnt/c/Users/<user>/.local/bin/ensure-openspec.sh` | `-rwxrwxrwx` | 45 |
| `~/.agent/bin/ensure-openspec.sh`(正典) | `-rwxr-xr-x` | 不在 PATH |

Linux 那份排最前但缺 exec bit,`command -v` 跳過後落到 WSL PATH interop 併入的 Windows 副本。若 exec bit 哪天被補回,命中的仍是同一份四月版 —— 兩條路都通向舊碼。`.chezmoiremove` 以目標相對路徑宣告,兩台機器各自 apply 時分別修剪。

新舊差異: 

| 舊副本(會被跑到) | 正典 `~/.agent/bin/ensure-openspec.sh` |
|---|---|
| `openspec init --tools claude` | `--tools "claude,codex,antigravity"` |
| 以 `.claude/commands/opsx` 判斷是否已初始化 | 以 `openspec/` 判斷 |
| 註解引用 `run_once_install-openspec`(已不存在) | `run_install-02-npm-tools` |

`dev-workflow` 以絕對路徑 `~/.agent/bin/ensure-openspec.sh` 呼叫,不受影響 —— 該 command 的唯一功能已被 workflow 涵蓋。

**PowerShell 中斷風險**:`$ErrorActionPreference = "Stop"` 下,native command 的非零 exit 不會 throw,但 `2>&1` 把 stderr 逐行轉成 `ErrorRecord`,在 `Stop` 下即為 terminating error。`run_onchange_` 失敗不記錄狀態,故會每次 apply 重試重失敗。

## Goals / Non-Goals

**Goals:**
- 移除會靜默降級 openspec 工具設定的路徑
- 讓 apply 輸出可信:訊息只在實際發生動作時出現
- 讓 `.ps1` 在嚴格模式下不因 plugin 指令的 stderr 中斷

**Non-Goals:**
- 把 `ensure-openspec` command 收進 chezmoi source(功能與 `dev-workflow` 重疊,使用者已裁定移除)
- 改動 `~/.agent/bin/ensure-openspec.sh` 本身(正典,無問題)
- 為 `.sh` 版補等效防護(`|| true` 已足夠,`set -e` 語義不同)

## Decisions

**[移除 command 而非修好它]**
修好它需要改成絕對路徑並更新 `opsx:new` 措辭,但修好之後它做的事等同 `dev-workflow` 開場的第一步。保留一個冗餘入口只是多一條需要同步維護、且已證明會漂移的路徑。

**[同時清 Windows 側的 `.local/bin/ensure-openspec.sh`]**
只刪 command 檔不夠 —— 舊腳本副本仍在 Windows 的 PATH 上,任何 bare 呼叫(人手打的、其他工具的)仍會命中它。`.chezmoiremove` 用目標路徑宣告,Windows 機器 apply 時即修剪。

替代方案:只刪 command。較小,但留著一顆已知會降級設定的地雷。捨棄。

<!-- evergreen-candidate -->
**[WSL 下腳本互相呼叫一律用絕對路徑]**
WSL 的 PATH interop 把 Windows 家目錄併入 PATH,同名腳本可能來自另一台機器、另一個年代。在這個雙棲 repo 裡,bare 名稱呼叫是跨 OS 的賭博;`~/.agent/bin/` 與 `~/.local/bin/` 的腳本互相呼叫應一律絕對路徑。

**[`.ps1` 全檔補齊 guard,而非只補 review 點名那行]**
同檔已有 `marketplace add` 的 `Continue`/`Stop` 三明治作為先例,其餘 `claude … 2>&1 | Out-Null` 是同一個失敗模式。只補一處會讓檔案內部標準不一,下一個讀者無從判斷哪些是刻意、哪些是遺漏。使用者已裁定全檔補齊。

**[以 section 級 `Continue` 取代逐行三明治]**
六個 `2>&1` 呼叫全在同一個 plugin 區段。逐行包夾要多 10 行雜訊,且下一個在區段內新增呼叫的人很容易漏包。改為整段設 `Continue`、段末還原 `Stop` —— 這也更貼近意圖:「plugin 段容忍失敗,其餘段不容忍」。既有的 `marketplace add` 三明治併入該區段。

**[其餘 native 呼叫稽核結果]**
- `claude plugin list 2>$null`(line 33)、`claude mcp list 2>$null`(line 149):`2>$null` 是丟棄而非併入 success stream,不產生 `ErrorRecord`,不受影響
- `dos2unix … 2>$null`(line 122):同上,且本就在既有的 `Continue` 區塊內
- `claude mcp add`(line 153):無重導向。native 非零 exit 在 PS 5.1–7.2 下不 throw;PS 7.4+ 的 `$PSNativeCommandUseErrorActionPreference` 預設開啟時會,但那是「非零 exit」而非本 change 處理的「stderr 轉 ErrorRecord」失敗模式,且 MCP 註冊失敗時中止腳本是合理行為。記錄為不適用,不改。

**[`.sh` 側不需對稱改動]**
`set -euo pipefail` 下 `|| true` 已涵蓋非零 exit,且 shell 不會把 stderr 轉成錯誤物件 —— 這是 PowerShell 特有的失敗模式,不是 parity 缺口。

## Risks / Trade-offs

**[`.ps1` 仍無法在 Linux 驗證]** → 與前次 change 相同限制:本機無 pwsh,template 的 Windows 守衛使其在 Linux 渲染為空。改動全為既有 `marketplace add` 三明治的複製,語法風險低,但需 Windows apply 確認。

**[與 PR #31 的 `.chezmoiremove` 尾端衝突]** → 兩分支都在檔尾附加區塊。先合併者不受影響,後者 rebase 時解一次瑣碎衝突。刻意不從 #31 分支疊 PR,以免 #31 若需返工連帶阻塞本 change。

**[移除 command 後使用者失去手動觸發入口]** → `dev-workflow` 開場即執行同一支腳本;若真需手動,直接跑 `~/.agent/bin/ensure-openspec.sh`。已與使用者確認。

## Migration Plan

1. 改 source 三檔
2. `chezmoi apply` 驗證:`.claude/commands/ensure-openspec.md` 消失、cache 清理訊息不再假陽性、腳本 exit 0
3. Windows 機器下次 apply 時修剪 `.local/bin/ensure-openspec.sh` 並套用 `.ps1` guard
4. Rollback:git revert;`.chezmoiremove` 條目移除後檔案不會自動復原,但兩者皆為已退役副本,無復原需求
