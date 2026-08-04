# herdr

[herdr](https://herdr.dev/) 是給 coding agent 用的終端多工器。skill 的同步機制見
[claude-code.md](claude-code.md) 的「外部 skill：herdr」章節；本文只記實測行為與陷阱。

驗證環境：herdr 0.8.0、WSL2，2026-08-04。

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

## 紀律

- 背景工作一律 `--no-focus`，不要搶走使用者的焦點。
- 目標一律用 `--current`、明確 pane id 或唯一 agent 名稱。省略目標會打到
  「UI 焦點所在的 pane」—— 那可能是使用者或另一個 client 的。
- 只關自己開的 pane。實驗要隔離就開 named session，不要碰 `herdr server stop`。
- 這個 Claude Code session 本身就跑在 herdr pane 裡（`HERDR_ENV=1`），
  所以上面每一條都不是理論問題。
