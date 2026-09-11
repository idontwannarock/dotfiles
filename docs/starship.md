# Starship

[Starship](https://starship.rs/) 跨平台終端機 prompt 設定。

## 管理方式

設定檔由 chezmoi 管理，來源是 `home/dot_config/starship.toml.tmpl`，部署到 `~/.config/starship.toml`。Starship 本身也會在 `chezmoi apply` 時自動安裝。

設定檔是模板，只有一處分平台：Windows 會多出一段關閉 git 模組的區塊（見下方「Windows 上關閉 git 模組」）。其餘內容三個平台完全相同。

**路徑不可更動。** `~/.config/starship.toml` 是 starship 唯一的預設搜尋路徑，`~/.config/starship/` 子目錄不會被讀取。設定檔找不到時 starship 不報錯，會套用內建預設值照常畫出 prompt——換言之放錯路徑跟正常運作長得一模一樣。設定曾經一度放在子目錄，`command_timeout` 因此靜默失效（見 `home/.chezmoiremove` 的說明）。若真要換路徑，必須同時在每個 shell 的 rc 匯出 `STARSHIP_CONFIG`。

## 設定說明

| 設定 | 值 | 說明 |
|------|-----|------|
| `command_timeout` | `5000` | 指令超時時間（毫秒）。**超時不報錯，模組直接消失**——見下方「command_timeout 太低會讓 prompt 漏報」 |
| `shell.disabled` | `false` | 啟用 shell indicator（預設關閉），顯示當前 prompt 屬於哪個 shell |

### Shell indicator

所有 shell 共用同一份設定，畫面完全相同，靠這個模組區分。Indicator 顯示在 `❯` 正前方。

| Shell | 顯示 |
|-------|------|
| Bash（Git Bash / Linux / WSL） | `bash` |
| Zsh（macOS） | `zsh` |
| Windows PowerShell 5.1 | `ps5` |
| PowerShell 7+ | `pwsh` |
| cmd | `cmd` |
| 其他 | `?sh` |

兩個容易踩到的預設值：

- `pwsh_indicator` 預設未設定，會退回 `powershell_indicator`，因此**不明確指定就無法區分 PowerShell 5.1 與 7+**。兩者的判別來自 starship 自己的 init script，它依 `$PSVersionTable.PSVersion.Major` 把 `STARSHIP_SHELL` 設為 `powershell` 或 `pwsh`；`~/Documents/shared-profile.d/90-prompt.ps1` 一份 profile 兩邊共用即可，版本判斷在執行期發生。
- `unknown_indicator` 預設是空字串，未知 shell 會靜默不顯示。這裡設為 `?sh`，讓異常看得見。

模組判斷依據是 init script 寫入的 `STARSHIP_SHELL` 環境變數，不是 parent process，因此顯示的是「執行過 starship init 的那個 shell」。

## 為什麼這份設定要分平台

同一支 starship，成本差三個數量級。實測中位數：

| 誰執行 | 檔案放哪 | `git status` | starship prompt |
|---|---|---|---|
| WSL git | `/home`（Linux 原生） | 7 ms | 15 ms |
| Windows git | `D:\`（Windows 原生） | 286 ms | 1248 ms |
| WSL git | `/mnt/d`（跨檔案系統界線） | 3591 ms | 1084 ms |

慢的不是 starship，是 Windows。三件事各自收費：

1. **開任何行程約 110 ms。** `cmd.exe`（344 KB）和 `starship.exe`（13 MB）成本相近（97–208 ms），所以不是在讀檔案內容，是 `CreateProcess` 本身。`git --version` 什麼都不做也要 283 ms。這台機器裝了 Windows Defender、CrowdStrike Falcon 與 ESET 三套安全軟體，但無法關掉來做對照組，所以**「防毒佔多少」未經證實**。
2. **找到 git repository 約 775 ms**，與 repo 大小無關。
3. **`git_status`** 小 repo 289 ms，大 repo 1014 ms。

上游對此有紀錄且不打算修：[starship#6875](https://github.com/starship/starship/issues/6875) 中維護者確認「這是 Windows 的問題，不是 PowerShell」，並在 Linux/WSL 上的 PowerShell 7 驗證過速度正常。

## Windows 上關閉 git 模組

Windows 分支關掉 `git_branch` / `git_status` / `git_state` / `git_commit`，並設 `directory.truncate_to_repo = false`。

**`truncate_to_repo` 必須一起關。** 那 775 ms 記在「第一個要求 repository 的模組」頭上，`truncate_to_repo` 就是讓 `directory` 去要的原因。只關 git 模組而留著它，`directory` 仍是 835 ms；兩個都關才會掉到 <1 ms。同理，只關 `git_status` 只省 289 ms。

實測效果：

| 目錄 | 關閉前 | 關閉後 |
|---|---|---|
| `D:\ws\github\dotfiles` | 1282 ms | 193 ms |
| `D:\ws\github\OpenSearch` | 2208 ms | 361 ms |

**WSL 不套用這段**，git 模組全部保留。Linux 原生路徑只要 15 ms，該有的資訊都在，而 git 工作主要在那裡進行。

代價：在 Windows 端的 repo 裡，prompt 不顯示 branch 與檔案狀態，要自己打 `git status`。

## command_timeout 太低會讓 prompt 漏報

超時的模組**不會報錯，會直接消失**。乾淨的 repo 看不出來——空字串本來就是正確答案。要有未 commit 的改動才現形。

在 `/mnt/d` 的 repo 放一個未追蹤檔實測：

| `command_timeout` | `git_status` 結果 |
|---|---|
| `1000` | `""`，prompt 顯示乾淨 ❌ |
| `5000` | `[?]`，耗時 1150–1560 ms ✅ |
| `30000` | `[?]` ✅ |

所以值定在 `5000`。提高上限在 git 夠快的地方沒有成本（Linux 原生路徑 9 ms、Windows 289 ms），**超時只在真的超過時才生效**。

## init 在 apply 時內嵌，不在開機時執行

`90-prompt.ps1` 的來源是 `home/Documents/exact__shared-profile.d/90-prompt.ps1.tmpl`。
`chezmoi apply` 用 `output` 函式呼叫一次 `starship init powershell --print-full-init`，把結果寫進檔案。開機時只讀檔，不再開行程。

原本的寫法每次開 shell 都問 starship 同一個問題：

| 步驟 | 成本 |
|---|---|
| `Get-Command starship`（掃 PATH） | ~83 ms |
| 開 `starship.exe` 拿 init 文字 | ~200 ms |
| 解析那 10,636 個字元 | 12 ms |
| 載入 PSReadLine + 執行 init（裡面**再開一次** starship.exe） | ~450 ms |

前兩項是內嵌省掉的。後兩項省不掉：**解析只要 12 ms**，貴的是執行，而 starship 的 init 程式碼自己會再開一次 `starship.exe` 去問接續提示字元。

實測 `90-prompt.ps1`：**1043 ms → 約 630 ms**（五次中位數 628 ms，散佈 609–1021）。pwsh 開機（含 profile）2.9 s → **約 1.9 s**。

這台機器的單次量測跳動很大，五次裡常有一次是其他次的 1.6 倍。只取一次會得到 477 ms 這種偏樂觀的數字——任何一項量測都要取中位數並記下散佈。

### 為什麼不能在 CI 渲染

init 文字裡有這台機器的絕對路徑：

```powershell
Invoke-Native -Executable 'C:\Users\user\.local\bin\starship.exe' ...
```

CI 不知道目標機器的家目錄，也不知道它裝的是哪一版 starship。所以渲染必須發生在**目標機器的 `chezmoi apply`**，不是 CI。

CI 仍然有用：`test-render.yml` 在三個 OS 上跑 `chezmoi apply --dry-run`，模板語法錯誤會被擋下。CI runner 上沒有 starship，`lookPath` 落空，走 fallback 分支——那條分支保留舊的開機時初始化寫法，所以沒裝 starship 的機器照樣能用。

### 升級 starship 之後要重跑 apply

內嵌的那段屬於「上次 apply 時的那個 binary」。版本對不上時 starship 會在每個 prompt 印：

```
error: Found argument '0' which wasn't expected, or isn't valid in this context
```

**是吵的，不是安靜的**（對照 `command_timeout` 那節，那個才會安靜消失）。再跑一次 `chezmoi apply` 即可。上游對這類不符有紀錄：[starship#3553](https://github.com/starship/starship/issues/3553)。
