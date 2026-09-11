# Windows 上的 Git PATH

Windows 端 `git` 指令的固定成本，以及為什麼 Machine PATH 上要多一條手動設定。

## 症狀

每個 `git` 指令在 Windows 上都有約 100 ms 的固定開銷，跟 repo 大小和磁碟無關。

| 指令 | 修正前 | 修正後 |
|---|---|---|
| `git log -1 --oneline` | 235 ms | 116 ms |
| `git status --porcelain` | 264 ms | 150 ms |
| `git --version`（什麼都不做） | 276 ms | 145 ms |

## 原因：PATH 上的 git 是一支啟動器

`C:\Program Files\Git\cmd\git.exe` 只有 46 KB。它不是 git，是 Git for Windows 的**啟動器** —— 先把 `usr\bin`、`mingw64\bin` 設進環境，再去執行真正的 `C:\Program Files\Git\mingw64\bin\git.exe`（4.2 MB）。

所以每下一個 git 指令，**都開了兩個行程**。

在這台機器上開一個行程要約 110 ms，與執行檔大小無關（`hostname.exe` 40 KB 要 108 ms，`starship.exe` 12.8 MB 要 173 ms）。成本掛在 `CreateProcess` 上，不是讀檔案。用 WPR 追蹤，CrowdStrike 的 `csagent.sys` 佔了其中 21%，其餘主要是 `ntoskrnl` 本身。詳見 [starship.md](starship.md)。

## 修正：把 mingw64\bin 插在 Git\cmd 前面

**位置很重要，必須是「在 System32 之後、在 `Git\cmd` 之前」。**

| 放哪 | 結果 |
|---|---|
| PATH 最前面 | ❌ `mingw64\bin` 裡的 `curl.exe` 會蓋掉 `C:\WINDOWS\system32\curl.exe` |
| **`Git\cmd` 正前方** | ✅ System32 仍在前面，`curl` 不受影響 |
| User PATH | ❌ Windows 的 PATH 是 Machine 先、User 後，搶不贏 `Git\cmd` |

**不要刪掉 `Git\cmd`。** 這些只存在於 `cmd\`，`mingw64\bin` 沒有：

```
git-gui.exe   tig.exe   start-ssh-agent.cmd
```

`gitk` 是例外，而且是這次唯一的回歸——見下一節。

## 唯一的回歸：PowerShell 裡的 `gitk`

`mingw64\bin` 裡有一個**沒有副檔名**的 `gitk`，內容是 `#!/bin/sh` 腳本：

```
mingw64\bin\gitk       409 KB   #!/bin/sh ... exec wish "$0" -- "$@"
cmd\gitk.exe           138 KB   真正的 Windows 執行檔
```

`mingw64\bin` 排在前面，所以 PowerShell 會先挑到那個腳本，然後拒絕執行：

```
無法在管線中間執行文件: C:\Program Files\Git\mingw64\bin\gitk
```

**cmd.exe 不受影響** —— `PATHEXT` 不含「無副檔名」，所以 cmd 會跳過它，直接找到 `cmd\gitk.exe`。

修法在 `home/Documents/exact__shared-profile.d/10-aliases.ps1`：

```powershell
Set-Alias gitk 'C:\Program Files\Git\cmd\gitk.exe'
```

別名是純名稱代換，不做參數繫結，所以沒有包裝函式的參數問題。實測成本 0 ms。

`mingw64\bin` 裡共有 20 個無副檔名的檔案（`bzgrep`、`xzless`、`wcurl`…），逐一比對過 `Git\cmd` 與 `System32`，**只有 `gitk` 一個有衝突**。

## 為什麼 chezmoi 管不到

Machine PATH 要系統管理員權限，chezmoi 是用一般帳號跑的。`run_onchange_before_setup-paths.ps1.tmpl` 只動得了 User PATH，而 User PATH 排在 Machine 之後，對這件事無效。

所以這是一條**手動設定**，重灌或換機器要重做。這份文件就是它唯一的紀錄。

## 設定腳本

用「以系統管理員身分執行」的 PowerShell 跑一次。

`SetEnvironmentVariable` **不能用** —— Machine PATH 的型別是 `REG_EXPAND_SZ`，裡面有 `%SystemRoot%\system32` 這種未展開的值，用它寫回去會把那些寫死成絕對路徑。必須直接讀寫登錄檔並保留型別。

```powershell
#requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$target  = 'C:\Program Files\Git\mingw64\bin'
$anchor  = 'C:\Program Files\Git\cmd'
$regPath = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
$backup  = "$env:USERPROFILE\machine-path-backup-$(Get-Date -Format yyyyMMdd-HHmmss).txt"
function Norm($s) { [Environment]::ExpandEnvironmentVariables($s).TrimEnd('\') }

if (-not (Test-Path "$target\git.exe")) { throw "找不到 $target\git.exe" }
$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($regPath, $true)
try {
    # DoNotExpandEnvironmentNames:保住 %SystemRoot% 這類未展開的值
    $raw  = $key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    $kind = $key.GetValueKind('Path')
    Set-Content $backup -Value $raw -Encoding UTF8
    Write-Host "已備份 -> $backup"

    $entries = @($raw -split ';' | Where-Object { $_ -ne '' })
    if ($entries | Where-Object { (Norm $_) -ieq (Norm $target) }) { Write-Host '已在 PATH 上,不動作'; return }

    $idxAnchor = -1; $idxSys32 = -1
    for ($i = 0; $i -lt $entries.Count; $i++) {
        if ((Norm $entries[$i]) -ieq (Norm $anchor))               { $idxAnchor = $i }
        if ((Norm $entries[$i]) -ieq (Norm 'C:\WINDOWS\system32')) { $idxSys32  = $i }
    }
    # 找不到就中止,不猜位置
    if ($idxAnchor -lt 0) { throw "Machine PATH 上找不到 $anchor" }
    # 守門:插在 System32 前面會蓋掉 Windows 的 curl.exe
    if ($idxSys32 -ge 0 -and $idxAnchor -le $idxSys32) { throw "$anchor 排在 System32 前面,中止" }

    $new = @()
    if ($idxAnchor -gt 0) { $new += $entries[0..($idxAnchor - 1)] }
    $new += $target
    $new += $entries[$idxAnchor..($entries.Count - 1)]
    $key.SetValue('Path', ($new -join ';'), $kind)
    Write-Host "已插入,$($entries.Count) -> $($new.Count) 筆"
} finally { $key.Dispose() }

# 廣播變更,之後開的視窗才讀得到
Add-Type -Namespace W -Name N -MemberDefinition @'
[DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam,
    string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
$res = [UIntPtr]::Zero
[void][W.N]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$res)
```

## 驗證

開一個**全新的**終端機：

```powershell
(Get-Command git).Source    # 應為 C:\Program Files\Git\mingw64\bin\git.exe
(Get-Command curl).Source   # 應為 C:\WINDOWS\system32\curl.exe
(Get-Command gitk).Source   # 應為 C:\Program Files\Git\cmd\gitk.exe
```

三項都對才算成功。只驗 `git` 一項會漏掉 `curl` 被蓋掉的情況。

## Git for Windows 更新之後

安裝程式只確保自己的 `Git\cmd` 在 PATH 上，**不會刪掉別人加的項目**，所以這條設定預期會留著。但這是依照它一貫的行為推斷，沒有保證 —— 升級後跑一次上面的驗證即可。

若要還原，備份檔裡是原始字串：

```powershell
$r = Get-Content 'C:\Users\<你>\machine-path-backup-<時間>.txt' -Raw
$k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
       'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', $true)
$k.SetValue('Path', $r.Trim(), 'ExpandString')
$k.Dispose()
```

## 已驗證可用的操作

直接執行 `mingw64\bin\git.exe`（不經啟動器）測過這些，全部正常：

- `init` / `config` / `add` / `commit`
- **pre-commit hook**（`#!/bin/sh`，需要 sh）
- **走 `sh` 的 alias**（`!echo ...`）
- `ls-remote` 走 SSH 到 GitHub
- `git --exec-path` 指向同一個 `libexec/git-core`

**未測**：git-lfs、HTTPS 的 credential manager、`git gui`、互動式 rebase。
