# 開機後在背景啟動 WSL

用排程工作在背景啟動 WSL 時，啟動方式會影響 Windows 端的 localhost 轉發。設錯時，Ghostex 連不到 WSL 裡的服務。

這個排程工作**不由 chezmoi 管理**。每台機器要手動建立。本文件只提供參考。

## 症狀

重開機後，Ghostex 顯示這個錯誤：

> WSL gxserver unavailable — A program Ghostex can't identify is listening on 127.0.0.1:58744 ... It belongs to another account or runs as administrator ...

WSL 裡的 `gxserver` 其實有正常啟動。用 `ss -ltnp` 可以看到它在聽 port。

## 原因：wslrelay 跑在 session 0

`wslrelay.exe` 是 WSL 內建的 localhost 轉發程式。檔案在 `C:\Program Files\WSL\`，有 Microsoft 簽章。它的父程序是 `wslservice.exe`。WSL 裡的程式開 port 時，`wslrelay` 在 Windows 端開同一個 port，再把連線轉進 WSL。

**`wslrelay` 跑在「第一個啟動 WSL VM 的程式」所在的 session。**

| WSL 由誰啟動 | `wslrelay` 的 session | 使用者能不能讀到它的擁有者 | Ghostex |
|---|---|---|---|
| 排程工作，觸發條件「啟動時」 | 0（服務 session） | 不能 | 出錯 |
| 桌面上的程式（終端機、Ghostex、登入觸發的工作） | 1（桌面 session） | 能 | 正常 |

Ghostex 會先檢查 port 的擁有者，確認是自己的服務才送出存取 token。在 session 0 的 `wslrelay`，一般使用者讀不到它的擁有者，所以 Ghostex 拒絕連線。

**權限等級（RunLevel）不是原因。** 只把「以最高權限執行」關掉，`wslrelay` 還是在 session 0，錯誤還在。

這個原因經過雙向測試確認（2026-11-10，WSL 3.0.3.0）：

1. 從桌面重啟 WSL：`wslrelay` 在 session 1，Ghostex 正常。
2. 用開機觸發的工作重啟 WSL：`wslrelay` 在 session 0，Ghostex 出錯。

## 檢查方法

看 `wslrelay` 在哪個 session、擁有者是誰：

```powershell
Get-CimInstance Win32_Process -Filter "Name='wslrelay.exe'" | ForEach-Object {
  $o = Invoke-CimMethod -InputObject $_ -MethodName GetOwner
  [pscustomobject]@{ Pid = $_.ProcessId; Session = $_.SessionId; Owner = "$($o.Domain)\$($o.User)" }
}
```

- Session 是 `1`，Owner 是你的帳號：正常。
- Session 是 `0`，Owner 是空的 `\`：會出錯。

## 立即恢復（不用重開機）

1. 執行 `wsl --shutdown`。
2. 在桌面上執行 `wsl -d Ubuntu -e true`。把 `Ubuntu` 換成你的 distro 名稱。
3. 用工作管理員關掉 Ghostex，再重開。

這個方法要搭配 `.wslconfig` 的 `instanceIdleTimeout=-1`。不然 `wsl -e true` 結束後，WSL 會自己關掉。

## 排程工作的建議設定

| 項目 | 設定 | 原因 |
|---|---|---|
| 觸發程序 | 登入時，指定自己的帳號 | 讓 WSL 在桌面 session 啟動 |
| 安全性選項 | 只在使用者登入時執行（Interactive） | 同上 |
| 權限 | 不勾「以最高權限執行」（Limited） | 啟動 WSL 不需要管理員權限 |
| 程式 | `C:\Windows\System32\conhost.exe` | 見下方說明 |
| 引數 | `--headless C:\Windows\System32\wsl.exe --distribution-id {<distro-id>} --exec sleep infinity` | 見下方說明 |

**為什麼要 `conhost.exe --headless`：** 工作改成在桌面執行後，`wsl.exe` 會開在預設終端機裡。Windows Terminal 會跳出一個空白的 tab。`conhost.exe --headless` 讓 `wsl.exe` 在背景執行，不開視窗。

**代價：** WSL 要等使用者登入後才會啟動。開機到登入之間，WSL 裡的服務不會執行。如果你需要「開機不登入也要跑」的服務，這個設定不適用。

用 `wsl -l -v` 看不到 distro ID。用這個指令從登錄檔查：

```powershell
Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss |
  ForEach-Object { "$($_.PSChildName) = $((Get-ItemProperty $_.PSPath).DistributionName)" }
```

也可以把 `--distribution-id {<distro-id>}` 換成 `-d <distro 名稱>`。

## 修改工作要管理員權限

在一般權限的 shell 執行 `Set-ScheduledTask`，會得到「存取被拒」。請用管理員 PowerShell。

如果工作的登入類型是「密碼」（「不論使用者是否登入都執行」），用 `Set-ScheduledTask` 改設定會出現「使用者名稱或密碼不正確」。這時改用工作排程器的圖形介面，它會跳出視窗要你輸入密碼。

把動作改成 headless 的指令（管理員 PowerShell）：

```powershell
$a = New-ScheduledTaskAction -Execute 'C:\Windows\System32\conhost.exe' -Argument '--headless C:\Windows\System32\wsl.exe --distribution-id {<distro-id>} --exec sleep infinity'
Set-ScheduledTask -TaskName StartWSLBackground -Action $a
```

觸發程序和安全性選項，這台機器是用圖形介面改的。
