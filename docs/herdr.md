# herdr

[herdr](https://herdr.dev/) 是給 coding agent 用的終端多工器。skill 的同步機制見
[claude-code.md](claude-code.md) 的「外部 skill：herdr」章節；本文只記實測行為與陷阱。

驗證環境：herdr 0.8.0、WSL2，2026-08-04；Windows 原生 0.8.0-preview，2026-08-05。

> binary 本身不由 chezmoi 安裝，用 `herdr update` 自行升版；升完下一次
> `chezmoi apply` 會偵測到版本變動並同步對應版本的 skill。

## 實測通過的路徑

| 動作 | 指令 | 結果 |
|------|------|------|
| 開 pane | `herdr pane split --current --direction right --cwd "$PWD" --no-focus` | 回 JSON，pane id 在 `.result.pane.pane_id` |
| 送指令 | `herdr pane run <pane> '<cmd>'` | 指令與 Enter 一次送出 |
| 等輸出 | `herdr pane wait-output <pane> --match TEXT --timeout 15000` | 命中即返回 |
| 讀回 | `herdr pane read <pane> --source visible --lines N` | **純文字，不是 JSON** |
| 收掉 | `herdr pane close <pane>` | — |
| 起 agent | `herdr agent start <name> --kind codex --pane <pane>` | 約 3 秒，回 `interactive_ready: true` |
| 派工並等待 | `herdr agent prompt <name> "<prompt>" --wait --timeout 180000` | block 到 agent 收斂成 idle/done/blocked |
| 讀 agent 回覆 | `herdr agent read <name> --source visible --lines 60` | Codex 跑在 alternate screen，`visible` 仍讀得到 |

派工給 Codex 的完整往返實測約 14 秒（起 agent 3 秒 + 一個讀檔問答 10.6 秒）。

## 陷阱

**`pane read` 的 source 選錯會靜默拿到空字串。** skill 寫「prefer `recent-unwrapped`
for logs and transcripts」，但 `recent` 與 `recent-unwrapped` 讀的是 host scrollback，
新開的 pane 還沒有內容捲出視窗，兩者都回空 —— 沒有錯誤、沒有非零 exit code。

實測（viewport 46 行）：

| 輸出量 | `visible` | `recent-unwrapped` |
|--------|-----------|--------------------|
| 一行 `echo` | 有內容 | **空** |
| `seq 1 200` | 46 行（視窗大小） | 209 行 |

規則：短輸出用 `visible` 或 `detection`；輸出超過視窗高度才改用 `recent-unwrapped`。

**控制指令吐 JSON，`read` 不吐。** `pane split`、`agent start`、`agent prompt` 等回
JSON（用 `.result.*` 取 id）；`pane read` / `agent read` 直接回純文字。拿 parser 去
接 `read` 會炸。

**id 從回應取，不要自己推。** pane id 形如 `wK:pV`，關閉後不重用，`pane move`
之後會換新 id。

**新 split 的 pane 還沒回到 shell prompt。** `agent start` 會拒絕（`agent_pane_busy`），
但過一兩秒同一個 pane 就可用。先等 prompt 再啟動，別把第一次拒絕當成失敗。

**沒有 `agent stop`。** agent 生命週期綁在 pane 上，收尾的正典是「送該 agent 自己的
結束指令（`/exit`）→ `pane close` → `agent list` 確認」。實測（codex 0.146.1）硬關
pane **不會**截斷 session 記錄：同一份工作在硬關前後皆為 14 行、結尾都是完整的
`task_complete`，也沒有留下 `ppid=1` 的孤兒行程。所以禮貌退出的價值只剩「讓有
session-end hook 的 kind 跑完 hook」，不要拿「保住 transcript」去主張它。

## 三種「看起來成功的失敗」

以下三項都不報錯、退出碼為零、狀態機也顯示收斂，是實際踩過才浮現的：

**`agent wait` 預設把 `blocked` 當收斂。** 但 `blocked` 意思是 agent 停在權限對話框
或澄清問題上，工作**沒有完成**。只有 `idle`/`done` 能當成功；照預設等待會在對方卡住時
讀到不完整或不存在的結果。

**`interactive_ready: true` 與收斂狀態都不保證 prompt 被處理。** 啟動後的第一個 prompt
可能被 agent 自己的啟動通知（usage limit 提示、MCP 失敗警告、自我更新）吞掉，而
`--wait` 照樣回報 `done`/`idle`、context 計數停在 0。判斷工作是否真的發生只能看它有沒有
產出約定的檔案 —— 缺檔就重送一次，再缺才放棄。

**agent 退出後，`agent prompt` 的文字會被 shell 當指令執行。** 實際踩到的路徑是 codex
啟動時自我更新完就退出，pane 回到 shell prompt，後續送出的 prompt 逐行變成指令：

```
❯ 1. Report your current working directory.
1.: command not found
```

那次剛好無害，但 prompt 是任意文字、cwd 是使用者的 repo。**每次送出前都要先確認 pane
仍由預期的 agent 佔用**；不在就走退化路徑，不要送。

## 限制對造 agent 的寫入範圍

關鍵是**工作目錄就是可寫根**，而且不要額外加目錄：

| kind | 限制方式 | 越界時 |
|------|---------|--------|
| codex | `--cd <repo> --sandbox workspace-write --ask-for-approval never` | 直接失敗（`read-only file system`），流程繼續 |
| claude | cwd 設為 repo，**不給 `--add-dir`** | 跳核准對話框 → `blocked`，流程停住 |

兩個反例：codex 的 `--sandbox read-only` 與 `--add-dir` **互斥**（明文拒絕「effective
permissions do not allow additional writable roots」）；claude 的
`--disallowedTools "Write(<repo>/**)"` **擋不住**，`--add-dir` 的授權是雙向的，路徑樣式
的否決蓋不過它。

也就是說沒有任何一種 kind 能做到「某子目錄可寫、其餘唯讀」。要唯讀就整個唯讀，
要能寫就整個工作目錄能寫 —— 於是 findings 檔只能落在工作目錄內。

## Windows 原生安裝

**只有 preview channel 有 Windows binary。** stable v0.8.0 的 release assets 只發
linux/macos 各兩種架構；`herdr-windows-x86_64.zip` 只出現在 `herdr.dev/preview.json`。
官方 `install.ps1` 直接把 stable 擋掉：

```
if ($Channel -eq "stable") { Write-Error "Windows builds are preview-only for now."; exit 1 }
```

安裝（PowerShell **5.1 或 7 皆可** —— 腳本最高只用到 `Expand-Archive`，無 PS7 專屬語法；
**不能用 bash**，`install.sh` 與 `install.ps1` 兩邊都會拒絕）：

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://herdr.dev/install.ps1 | iex"
```

| 項目 | 值 |
|------|-----|
| binary | `%LOCALAPPDATA%\Programs\Herdr\bin\herdr.exe` |
| 版本目錄 | `%USERPROFILE%\.herdr\packages\standalone\releases\` |
| PATH | 寫入 `HKCU\Environment\Path`（prepend） |
| 版本字串 | `0.8.0-preview.<date>-<sha>` —— 帶 prerelease |

zip 內含 **app-local ConPTY runtime**（`conpty.dll` + x64/arm64 `OpenConsole.exe`），
不要只把 `herdr.exe` 複製走。ARM64 機器會裝 x86_64 版跑模擬。

官方列的 Windows beta 限制：PowerShell pane 啟動後改變 cwd 不會可靠回報、
`herdr --remote` 不在 beta 範圍、游標會閃爍跳位、`shift+enter` 只在 terminal
回報為獨立鍵時有效。supported 的是 PowerShell 與 cmd.exe pane，terminal 建議
Windows Terminal。

## Windows 陷阱

**改了 registry PATH，chezmoi 不會自己看到。** `.chezmoi.toml.tmpl` 的 `[scriptEnv]`
PATH 是從 registry（Machine + User）讀出來後**渲染進 `~/.config/chezmoi/chezmoi.toml`
就凍結**的 —— 而該檔只在 `chezmoi init` 重新產生。herdr 的 install.ps1 正好會 prepend
registry PATH，所以裝完的當下：registry 有、config 沒有、`lookPath "herdr"` 回空、
run_*/modify_* 子行程的 PATH 也沒有。

```
registry User PATH has it?  : True
config PATH contains Herdr? : False
lookPath                    : []
```

`run_onchange_before_patch-chezmoi-config.ps1.tmpl` 已經會 self-heal：expected PATH
渲染進腳本，所以 registry PATH 一變、run_onchange_ 的 hash 就變、腳本剛好在該重跑時
重跑。但**修好的 config 要下一次 apply 才生效**（chezmoi 在啟動時就讀完 config 了），
所以裝完新工具後跑兩次 `chezmoi apply`，或直接 `chezmoi init`。

這不是 herdr 專屬 —— 任何改 registry PATH 的安裝都一樣。

**`herdr --skill` 在 Windows 吐 CRLF。** MSYS 的 text mode 會讓 Git Bash 裡的
`head`/`grep` 讀起來像沒事（驗證全過），但落到磁碟上的 `SKILL.md` 仍帶 `\r`：

```
raw          : 10335 bytes, 195 個 CR
tr -d '\r'   : 10140 bytes, 0 個 CR
```

skill 安裝腳本因此固定跑一次 `tr -d '\r'`（Unix 端是 no-op）。

## 紀律

- 背景工作一律 `--no-focus`，不要搶走使用者的焦點。
- 目標一律用 `--current`、明確 pane id 或唯一 agent 名稱。省略目標會打到
  「UI 焦點所在的 pane」—— 那可能是使用者或另一個 client 的。
- 只關自己開的 pane。實驗要隔離就開 named session，不要碰 `herdr server stop`。
- 這個 Claude Code session 本身就跑在 herdr pane 裡（`HERDR_ENV=1`），
  所以上面每一條都不是理論問題。
