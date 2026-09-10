# Windows SSH 走不進 junction

Windows 上透過 SSH 進來時，**走訪不了桌面身分建立的 junction**（`mklink /J`）。
symlink（`mklink /D`）不受影響。這條差異是本 repo 把整套工具鏈遷出 Scoop 的根因，
也是評估任何新版本管理器時的第一道篩子。

驗證環境：Windows 11、Win32-OpenSSH、PowerShell 5.1，2026-09-10。實測於本機 localhost SSH。

## 症狀

SSH session 內，junction 的目錄本身看得到，但走不進去：

```
Test-Path C:\...\link_junction              -> True
Test-Path C:\...\link_junction\canary.txt   -> False
[IO.File]::ReadAllText(...)                 -> The path cannot be traversed
                                               because it contains an untrusted mount point.
```

同一個路徑在桌面 session 下完全正常。

## 根因

錯誤是 `ERROR_UNTRUSTED_MOUNT_POINT`，數值 `0x1C0` = **448**。
（舊 design doc 裡的「os error 448」就是它。Win32 錯誤碼文件從 403 跳到 487，所以查不到名字。）

規則：**權限較高的行程，不准走訪權限較低的身分建立的 junction。**

這是 Windows 的防重導向機制。junction 不需任何權限就能建立，低權限使用者可以「種」一個
junction 去騙高權限行程存取別的位置，所以核心直接拒絕。

三組實測，同一台機器、同一個帳號：

| 建立 junction 的身分 | 走訪的身分 | 結果 |
|---|---|---|
| Medium（桌面） | Medium（桌面） | 讀得到 |
| High（SSH） | High（SSH） | 讀得到 |
| **Medium（桌面）** | **High（SSH）** | **untrusted mount point** |

## 為什麼 SSH 是 High integrity

`sshd` 以 SYSTEM 執行，建立登入 token 時**不套用 UAC 過濾**。帳號若在本機
Administrators 群組內，SSH 就會拿到**完整的提權 token**（High IL）；桌面 session 拿到的是
UAC 過濾後的 token（Medium IL）。

佐證——建立 symlink 需要 `SeCreateSymbolicLinkPrivilege`：

```
SSH  : cmd /c mklink /D ... -> symbolic link created
桌面 : cmd /c mklink /D ... -> You do not have sufficient privilege
```

所以 SSH session 是實質提權的。這也表示 SSH 下不會跳 UAC 提示。

## 為什麼 symlink 免疫

因為**建立 symlink 本身就需要權限**（見上方實測）。低權限使用者種不出 symlink，
它就不可能是攻擊載體，核心也就沒有理由不信任它。

junction 相反：誰都能建，所以誰都不能信。

**這個不對稱是設計，不會隨版本消失。**

## 對工具選型的意義

任何在 Medium 身分下動態建立 junction 的工具，在 SSH session 下必然失效。已知案例：

| 工具 | junction 用在哪 | 處置 |
|---|---|---|
| Scoop | 每個 app 的 `current` | 全部遷出（Wave 1–12） |
| uv | `cpython-3.13` -> `cpython-3.13.13` 版本別名 | 關掉 trampolines，改 `.cmd` wrapper 直指真實目錄 |
| fnm | `src/fs.rs` 在 Windows 用 `junction::create` | **不採用**，見 `.chezmoiexternal.toml` 的 nvm 註解 |
| nvm-windows | `NVM_SYMLINK` 是 `mklink /D` symlink | 可用，這正是選它的原因 |

判斷方式：看工具是用 `mklink /J`（junction、危險）還是 `mklink /D`（symlink、安全），
或者根本不用 reparse point（真實路徑最安全）。

## 已知的處置選項

| 方案 | 說明 |
|---|---|
| 避開 junction（現行） | 已完成。缺點是每遇到新工具要重查一次。 |
| 讓 SSH session 降到 Medium | 根因修復，但 Win32-OpenSSH 沒有發過濾後 token 的設定項。 |
| 移出 Administrators | SSH 會拿到 Medium token，但同時失去提權能力。 |
| 關閉 redirection trust 緩解 | 弱化安全機制，公司機器不宜。 |

## 與 Tailscale 的關係

沒有關係。Tailscale SSH 的 server 元件只支援 Linux 與 macOS，Windows 只能當 client。
從手機或其他裝置經 Tailscale 連進這台 Windows，走的仍是同一個 Win32-OpenSSH，
拿到的仍是同一個 High IL token，行為完全一致。

## 重現方式

```powershell
$b = "$env:TEMP\jtest"
New-Item -ItemType Directory -Force "$b\real" | Out-Null
Set-Content "$b\real\canary.txt" "CANARY"
cmd /c mklink /J "$b\link" "$b\real"          # 在桌面 session 執行

# 然後從 SSH session 執行：
Test-Path "$b\link\canary.txt"                # False
[IO.File]::ReadAllText("$b\link\canary.txt")  # untrusted mount point
```

用完記得 `cmd /c rmdir "$b\link"` 再刪掉 `$b`，不要用 `Remove-Item -Recurse` 直接刪
含 junction 的目錄。
