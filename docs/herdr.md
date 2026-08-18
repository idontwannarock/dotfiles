# herdr

[herdr](https://herdr.dev/) 是給 coding agent 用的終端多工器。skill 的同步機制見
[claude-code.md](claude-code.md) 的「外部 skill：herdr」章節；本文只記實測行為與陷阱。

驗證環境：herdr 0.8.0、WSL2，2026-08-04；Windows 原生 0.8.0-preview，2026-08-05。

> binary 本身不由 chezmoi 安裝，用 `herdr update` 自行升版；升完下一次
> `chezmoi apply` 會偵測到版本變動並同步對應版本的 skill。

## config.toml 由 chezmoi 部分納管

**herdr 自己會寫這個檔** —— onboarding 完成後寫 `onboarding = false`，
`herdr config reset-keys` 會重寫 keybindings。所以整檔渲染會在每次 apply 把它們抹掉，
納管方式是 `modify_` script：只覆寫少數幾個 key，其餘原樣放行。

| 管住的 key | 範圍 | 為什麼 |
|---|---|---|
| `terminal.default_shell` | Windows | 見下一節，不設會退回 PowerShell 5.1 |
| `ui.sound.enabled = false` | 全平台 | 不要響 |

`onboarding`、`theme`、`ui.*` 的其餘項目、`[keys]` 一律**不管** —— 那是 herdr 和使用者
各自機器上的事。

herdr 每個 OS 讀不同路徑（`herdr --help` 最後一行會印出實際位置），而 chezmoi 的
source path 就決定 target path —— 一份來源檔蓋不了兩個路徑。因此腳本本體集中在
`.chezmoitemplates/scripts/herdr-config.sh`，各 OS 只放一行 wrapper：

| OS | source | target |
|----|--------|--------|
| Windows | `home/AppData/Roaming/herdr/modify_config.toml.sh.tmpl` | `%APPDATA%\herdr\config.toml` |
| Linux/WSL | `home/dot_config/herdr/modify_config.toml.sh.tmpl` | `~/.config/herdr/config.toml` |

`.sh` 是給 `[interpreters.sh]` 認的，chezmoi 在決定 target 名稱時會剝掉，所以落地是
`config.toml`。注意 `chezmoi target-path` **不會**做這個剝除（回報 `config.toml.sh`），
要確認實際目標請看 `chezmoi managed`。

macOS 不部署（`.chezmoiignore.tmpl` 排除）：沒有 Mac 可確認 herdr 走 `~/.config`
還是 `~/Library/Application Support`，猜錯就是留一個 herdr 不讀的死檔。

**`ensure` 必須是不動點。** 拿自己上一輪的輸出再跑一次要逐字節相同，否則每次 apply
都長一行（`run_after_modify-codex-config.ps1.tmpl` 就是踩過這個坑）。做法是「先刪掉該
key 在該 table 下的所有出現，再插回 table header 的下一行」—— 位置只由 header 決定，
與上一輪輸出無關。因此**落地的檔案裡不放註解**，理由寫在來源腳本與本文。

要主動砍掉某個 key 得加一個對稱的 `drop()`：modify_ 是 patch 不是 render，把 `ensure`
那行刪掉只代表新機器不會拿到，已部署的機器會永遠留著 —— 跟 `.chezmoiremove` 是同一
個道理。

改完設定要 `herdr server reload-config` 才會套到已在跑的 server。

## Windows pane 預設是 PowerShell 5.1

herdr 的 `default_shell` 說明寫「Empty means `$SHELL`, then `/bin/sh`」—— 那是 Unix
視角。Windows 沒有 `$SHELL`，於是落到內建 fallback `powershell.exe`，也就是系統自帶的
**5.1**。用 PowerShell 7 啟動 herdr 也沒用：pane 的 shell 是 herdr **server** 生子行程
時決定的，不繼承 client 的 shell。症狀是 pane 裡 starship 與所有 PS7 profile 的 alias
全部消失。

`modify_` 腳本因此在 Windows 明寫這個 key（值由 `lookPath "pwsh"` 渲染，取不到才退回
MSI 預設路徑）：

```toml
[terminal]
default_shell = "C:/Program Files/PowerShell/7/pwsh.exe"
```

**路徑要用正斜線。** TOML basic string 會把 `\` 當跳脫字元，`"C:\Program Files\..."`
直接壞掉。正斜線在 Windows API 上照樣可用。

改完只有**新開的 pane** 會生效 —— 既有 pane 是已經 spawn 的行程。

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

## 重開機後的復原

（2026-08-14、08-15 於 herdr 0.8.0、WSL2 實測；程式碼引用對照 `herdrdev/herdr` main。）

狀態正典是 `~/.config/herdr/session.json`（version 3），**每次變更即時寫檔**，不是關閉時
才寫：單一份 server log 裡 `persist.save` 3177 次。因此 **detach 的方式與復原無關** ——
16 次 `app.startup` 只對到 6 次 `app.shutdown`，其餘 10 次是 WSL 被硬殺，而每次
「關機前最後一次 save」與「重開後 `persist.restore`」的 workspace 數字都一致
（10→10、9→9、8→8）。不必為了保狀態去追求優雅關閉。

**存的是骨架，不是內容。** 每個 pane 只留 `cwd` 與 `agent_session`，tab 留 `custom_name`／
`layout`／`focused`，workspace 留 `custom_name`／`identity_cwd`／`active_tab`。行程、
scrollback、pane 裡進行中的任何東西都不存 —— 復原後每個 pane 是 `pane.spawn.start` 開出來
的全新 shell，cwd 對、畫面空。「重開後長得不太一樣」多半就是這個，加上**沒自訂名字的
workspace 只剩 `identity_cwd`**，辨識度差很多。常用的 workspace／tab 請命名。

**pane 的 cwd 是跟著 `cd` 走的。** `AppEvent::TerminalCwdReported` 收到新 cwd 就寫進 terminal
狀態並 `mark_session_dirty()`，所以持久化的是 pane **當下**的 cwd，不是它被建立時的。實測：
新開一個 cwd 在 dotfiles 的 pane → `cd ~/devops` → 下一次 save 之後 session.json 記的就是
`~/devops`。在 pane 裡 `cd` 去別的 repo，重開機後那個 workspace 就在新地方開，workspace 的
`identity_cwd`（sidebar 的 branch/git status 靠它）也跟著漂走。跨 repo 開新 workspace，不要
在既有 pane 裡 `cd` 過去。

agent 的自動 resume 由 `[session] resume_agents_on_restore` 控制（0.8.0 預設 true）。
`herdr config check` 會抓出打錯的 key（實測打錯一個字母回 `unknown config key ...; ignoring key`），
改完用 `herdr server reload-config` 生效。2026-08-15 一次真實重開機的成績：10 個 workspace、
19 個 pane、7 個 agent 全部自動回來，7 個 `claude --resume` **全部成功**。

## pane↔session 對應會記錯

這是目前唯一需要人介入的環節，而且它**不會報錯**。

**`claude --resume <uuid>` 是全域解析 uuid，不受 cwd 限制。** 所以 herdr 就算拿著別的 pane 的
session id，resume 照樣會成功 —— 傷害不是「接不起來」，而是**對話在錯的工作目錄裡被接起來**，
然後開始讀寫錯的 repo。2026-08-15 那次重開機，7 個 resume 全成功，其中 3 個 cwd 是錯的；
其中一個對話（整段都在 `mms_product_grouping_api`）被接到 qa-portal，transcript 裡多了一筆
cwd 是 qa-portal 的紀錄。

**結構性原因是身分被放在訊息裡，而不是通道裡。** hook（`~/.claude/hooks/herdr-agent-state.sh`）
把 session id 連同 `pane_id = $HERDR_PANE_ID` 送進 socket，server 的
`handle_pane_report_agent_session` 直接 `parse_pane_id(&params.pane_id)` 就採用，**從不檢查
回報的行程是否真的活在那個 pane 裡**。而 `HERDR_PANE_ID` 會被所有子行程繼承 —— 從某個 pane
的環境衍生出去的行程（背景 job、從別的 agent 的 shell 裡起的 agent）都帶著一個不屬於自己的
pane id。上游 issue **#2012（OPEN）** 記錄的是同一個信任邊界在 `herdr pane current` 上的版本。

這些資訊沒有一項是真的不可知的：

| 事實 | 權威來源 | herdr 現況 |
|------|---------|-----------|
| workspace／tab／pane 拓樸 | herdr 自己 spawn 的 | 確定 |
| pane 裡有哪些行程、誰在前景 | OS | 已經在查（`child_pid()`、`foreground_process_group_id()`） |
| **回報者住在哪個 pane** | OS，kernel 可驗證 | **靠 `$HERDR_PANE_ID` 自稱** |
| agent 當下的 session id | agent 自己 | hook push，確定 |

Unix socket 的連線本身帶著 kernel 給的、無法偽造的對端 pid（`SO_PEERCRED`；Windows 具名管道有
`GetNamedPipeClientProcessId`），配上 herdr 已經握有的 `child_pid()` 就能確定地解出回報者屬於
哪個 pane。但整個 `src/` grep 不到任何一處使用 —— 於是 `set_agent_session_ref_for_session_start`
只能用 `process_present`、`session_anchored`、seq 新鮮度、suppression 去**猜**「這筆回報像不像
真的」。CHANGELOG 在這塊反覆修過 #511、#712、#943、#1789、#1927、#2159，可見猜錯是常態。

**實測：server 完全不驗證。**（2026-08-18，herdr 0.8.0）開兩個空 pane A、B，從 **A 的 shell**
送一筆指名 **B** 的回報：

```bash
herdr pane report-agent-session <B> --source herdr:claude --agent claude \
      --agent-session-id 00000000-dead-beef-0000-000000000000 \
      --seq $(date +%s%N) --session-start-source startup
```

B **完全沒有跑任何 agent**（`agent: None`），假 id 照樣黏上去，而且**寫進了 session.json** ——
也就是說下次重開機，herdr 會拿這個捏造的 id 去 `claude --resume`。無錯誤、無警告。

**具體觸發條件仍未查明。** 2026-08-15 重開機後 7 個 claude 行程的 `HERDR_PANE_ID` 全部正確，
仍新增一筆污染；2026-08-18 又見同型複發（**沒有經過重開機**：兩個不同 repo 的 pane、兩邊 env
都正確，晚起的那個被記成早起那個的 session id）。所以「env 過期」不是解釋。但驗證對端 pid 能
讓**整類**問題消失 —— 不需要先找出兇手。

**好消息是它可自癒。** 只要該 pane 的 agent 重新啟動一次，hook 就會重報正確的 id，紀錄自動
修好 —— 缺的只是「知道哪幾筆錯了」。

### 檢查與修復

`herdr-session-check`（本機 `~/.local/bin`，尚未進 chezmoi）比對每個 agent pane 的 cwd 與
**transcript 第一筆記錄的 cwd**。不用 project 目錄名反推：slug 會把 `/` `_` `.` 全換成 `-`，
反推不回去。錯配時它印出正確的 `claude --resume` 指令與該 cwd 最近的候選 session；exit 1。

修法（實測過三次）：在該 pane 送 `/exit` → 確認 pane 回到 shell → 在 **cwd 正確的 pane** 執行
`claude --resume <id>`。transcript 不會受影響，重啟同時也把 herdr 的紀錄修回來。

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
