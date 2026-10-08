# Codex CLI 設定

這個 repo 也會管理 Codex CLI 的基礎設定，目標不是硬把 Claude Code 的概念照搬，而是用 Codex 原生能力達成接近的操作體驗。

> 本文件記載 Codex 端的設定內容與操作方式。跨 change 反覆適用的判斷依據(為什麼這樣設計)在 [`context/`](../context/index.md);可驗收的行為契約在 `openspec/specs/`。

## 安裝

`run_install-04-codex-cli` 用 OpenAI 官方 installer 安裝 Codex CLI。官方 README 把這個方式列在第一位。

| 平台 | installer | 執行檔位置 |
|------|-----------|-----------|
| Windows | `https://chatgpt.com/codex/install.ps1` | `%LOCALAPPDATA%\Programs\OpenAI\Codex\bin\codex.exe` |
| macOS / Linux / WSL | `https://chatgpt.com/codex/install.sh` | `~/.local/bin/codex` |

- 兩個平台的實際檔案都放在 `~/.codex/packages/standalone/`。
- 每次 apply，腳本從 `https://releases.openai.com/codex/channels/latest` 讀最新版本號。版本和本機不同時，才執行 installer。
- 版本由 chezmoi 管，不由 Codex 自己更新。原因見下面的「CLI 與背景 daemon 的版本由 chezmoi 統一」。
- 腳本用執行檔的完整路徑讀版本，不用 `Get-Command` / `command -v`。舊 Node 留下的 `codex` shim 曾經讓檢查以為已經裝好，結果跳過安裝。
- Windows 的 installer 會把它的 bin 目錄加到 User PATH 最前面。新開的 shell 才看得到。
- Unix 的 installer 在 bin 目錄不在 PATH 上時，會在 shell profile 加一段 PATH。這些 profile 由 chezmoi 管理，所以腳本先把 `~/.local/bin` 放進 PATH，讓 installer 跳過這一步。
- 以前用 npm 的 `@openai/codex` 安裝。`run_install-02-npm-tools` 現在會移除它。installer 發現 npm 版時也會改 shell profile，所以移除必須在 install-04 之前。

npm 版只是一層 Node wrapper，裡面跑的是同一個 `codex.exe`。換成官方 installer 後，Codex 不再依賴 Node：換 Node 版本或位置時，Codex 不會跟著消失。

## 設定位置

| 項目 | 部署目標 | 說明 |
|------|----------|------|
| Global config | `~/.codex/config.toml` | 預設 model/effort、profiles、project doc fallback、輕量指令 |
| Project config | repo `.codex/config.toml` | 此 repo 的專案層級覆寫 |
| Personal skill | `~/.codex/skills/codex-claude-parity/SKILL.md` | 將 Claude workflow 轉成 Codex 的 skill |
| Project instructions | repo `AGENTS.md` | 專案層級記憶與工作規則 |

## 這套配置做了什麼

預設使用 `gpt-6-astra`，reasoning effort 為 `high`。這個 dotfiles repo 透過
`.codex/config.toml` 將 effort 覆寫為 `medium`；project config 只會在信任此 repo
時載入。

### 1. 保留 Codex 原生行為

不使用 `model_instructions_file` 覆蓋內建 prompt，而是用較輕量的 `instructions`、`AGENTS.md` 與 skill 疊加行為。這樣比較穩，也比較符合 Codex 官方建議。

### 2. 對齊 Claude 的工作節奏

`codex-claude-parity` skill 會引導 Codex 在非瑣碎任務時先做三件事：

1. 決定要不要走結構化流程
2. 判斷是小型還是大型任務
3. 決定逐步確認還是自動推進

這對應你現在 `~/.claude/CLAUDE.md` 裡的做法，但改用 Codex 的語彙與能力表達。

Claude 端是 command 的能力（`/handoff`、`/pickup`、`/code:review-architecture`）在 Codex 一律包成 skill，部署到 `~/.codex/skills/<name>/`，與 Claude 共用 `.chezmoitemplates/skills/<name>.md` 的同一份 body —— 行為相同，只有 frontmatter 依各工具慣例不同。

其中 `code:review-architecture` 的檔案方位與實跑經驗見 [claude-code.md](claude-code.md) 的 Arch Review 章節，行為契約見 [`openspec/specs/review-architecture/spec.md`](../openspec/specs/review-architecture/spec.md)。

八支 `review-*` skill 同樣共用 body。它們的觀點放在 `~/.agent/reference/review-lenses/` —— tool-agnostic 的純檔案，兩端指向同一批路徑。這對 Codex 特別重要：改制前拿到的是一張列著 `subagent_type` 名字的表，那些 agent 只存在於 Claude 端，Codex 實際能讀到的只有表格裡那一行 focus 說明。派工方式是 body 裡少數的 reader-axis 分支之一：Claude 用 Agent tool 派 `reviewer`，Codex 用 `spawn_agent` 派，兩端都是一個 lens 一個 agent、同一輪平行送出。差別在唯讀性怎麼來：Claude 的 `reviewer` 由 `tools` 欄位鎖死，Codex 的 spawned agent 與呼叫者同工具，唯讀只能寫進指令裡。細節見 [claude-code.md](claude-code.md) 的 Code Review 章節。

唯一的例外是 `herdr`：它從上游同步而非自家撰寫，也不走 chezmoi 的檔案管理——
`run_onchange_install-herdr-skill.sh.tmpl` 依本機 herdr 版本抓對應 tag 的 SKILL.md，
同一份內容同時寫進 Claude 與 Codex 的 skill 目錄。該腳本寫入前會驗 description 有加
引號，因為 Codex 的 YAML frontmatter parser 比 Claude 嚴格；驗不過就保留舊檔並警告。
細節見 [claude-code.md](claude-code.md) 的「外部 skill：herdr」。

### 3. 讓 Codex 能讀既有專案慣例

`config.toml` 設定了：

- `project_doc_fallback_filenames = ["CLAUDE.md"]`

也就是說，若專案沒有 `AGENTS.md`，但有 root `CLAUDE.md`，Codex 仍可把它當成 project doc。對已經有 Claude 傳統的 repo 比較友善。

### 4. 提供常用 profile

- `quick`：快速處理瑣碎任務
- `deep`：較高推理深度，適合實作或重構
- `research`：研究/查證模式，啟用 live web search

### 5. 固定 TUI 顯示偏好

`config.toml` 設定 `tui.alternate_screen = "never"`，讓 Codex CLI 避免使用 terminal alternate screen。這比較接近 Windows Terminal / PowerShell 7 的 native scrollback 模式，可降低 full-screen redraw 後舊內容消失或黑屏的機率。

`tui.status_line` 同步目前選好的 footer 欄位：

```toml
["model-with-reasoning", "current-dir", "git-branch", "context-used", "five-hour-limit", "thread-title"]
```

### 6. Slack plugin

chezmoi 會在 Codex CLI 可用後執行以下命令，確保官方 curated Slack plugin 已安裝
且啟用：

```bash
codex plugin add slack@openai-curated --json
```

`run_install-04-codex-plugins` 每次 apply 都會先讀取 `codex plugin list --json`，
並以 plugin 的 `name`（`slack`）比對，不是以 `pluginId` 比對。Codex 回報的
`pluginId` 帶 marketplace 名稱，而該名稱每台機器不同：Windows 是
`openai-curated`，WSL 是 `openai-curated-remote`。用 `pluginId` 比對會永遠比不中，
使每次 apply 都重裝一次。plugin 已安裝且啟用時，腳本不會重裝。plugin 被移除或停用時，下一次 apply 會修復
狀態。Codex CLI 暫時不存在時，腳本會略過，並在下一次 apply 重試。

Slack 的帳號連線由 plugin 管理。若 Codex 顯示連線提示，請在該機器完成一次互動式
登入，再開一個新 session。OAuth credential、Slack client ID 和 token 都不會寫入
dotfiles。

不要再執行 `codex mcp login slack`。Slack MCP 不支援 Codex 對直接 remote MCP 使用
的 dynamic client registration。同步的 config 因此不再包含
`[mcp_servers.slack]` 或 `https://mcp.slack.com/mcp`。可用以下命令確認本機狀態：

```bash
codex plugin list --json
codex mcp get slack  # 預期回報找不到名為 slack 的直接 MCP server
```

Codex plugin registration 位於每台機器的 `[plugins.*]` config tables。chezmoi 會保留
所有這類 tables，和既有的 `[projects.*]` per-machine 設定相同。

`~/.codex/config.toml` 保留的 per-machine tables 共五種：`[projects.*]`、`[plugins.*]`、
`[hooks]`、`[hooks.*]` 與 `[features]`。`[features]` 裡的 hooks 開關決定
`~/.codex/hooks.json` 跑不跑；那個檔由 herdr 產生、不受 chezmoi 管，所以開關只能保留
不能管理。丟掉它不會報錯，只會讓 SessionStart hook 安靜地停止觸發。

### 單一 repo 的設定要放 repo 內，不要放 `[projects."<路徑>"]`

`~/.codex/config.toml` 的 `[projects."<路徑>"]` 不是設定層。Codex 只從這張表讀
`trust_level`，其他 key 一律不讀，也不驗證。寫進去的 `model`、`reasoning_effort`、
`approval_policy`、`sandbox_mode` 都不會生效，而且不會報錯。

單一 repo 的設定放在該 repo 的 `.codex/config.toml`。這一層有兩個條件：

- **repo 必須被信任。** 這一層只在 `[projects."<路徑>"]` 有 `trust_level = "trusted"`
  時才載入。信任是每台機器各自的狀態，不隨 chezmoi 同步。
- **key 用頂層的名字。** 寫 `model_reasoning_effort`，不寫 `reasoning_effort`。
  `approval_policy` 的合法值只有 `on-failure`、`on-request`、`never`。

| 想要的範圍 | 放哪裡 | 是否跨機器同步 |
|------------|--------|----------------|
| 所有 repo | `home/dot_codex/modify_config.toml` 的全域區塊 | 是，經 chezmoi |
| 單一 repo | 該 repo 的 `.codex/config.toml` | 是，經 git |
| 信任某個目錄 | `~/.codex/config.toml` 的 `[projects."<路徑>"]` | 否，每台機器各自建立 |

repo 內的 `.codex/config.toml` 會跟著 repo 公開。內容不適合公開時，不要放進 repo。

實測(codex-cli 0.155.0，2026-09-18)：在乾淨的 `CODEX_HOME` 裡，`sandbox_mode = 12345`
放在檔案頂層會讓 config 載入失敗，放在 `[projects."<路徑>"]` 裡則 parse ok。同樣四個
key 放進 repo 的 `.codex/config.toml`，四個都生效。拿掉 `trust_level` 之後，repo 的
`.codex/config.toml` 不再載入。

### CLI 與背景 daemon 的版本由 chezmoi 統一

Codex 的背景 daemon（app-server daemon）有自己的一份 Codex，位置在
`~/.codex/packages/app-server-daemon/current/bin/codex`。rc（`codex remote-control`）和
手機、桌面 app 都連到這個 daemon，所以 daemon 不能關。

預設情況下，daemon 每小時自己更新一次。以前用 npm 裝的 CLI 不會自己更新。CLI 落後之後，
daemon 會拒絕 CLI，畫面顯示「Background server has incompatible feature settings」。
這是官方的已知問題（[#51763](https://github.com/openai/codex/issues/51763)）。

改用官方 installer 之後，仍然保留這個做法。官方 installer 裡有一個更新程式，看起來會同時更新
CLI 和 daemon。但官方文件沒有寫這件事，所以不依賴它。

`run_install-04-codex-cli` 在每次 apply 時做三件事：

1. 用官方 installer 把 CLI 升到最新版。
2. 在 `~/.codex/app-server-daemon/settings.json` 寫入 `updater.autoUpdateEnabled = false`，
   關掉 daemon 的自動更新。
3. daemon 的版本和 CLI 不同時，執行 `codex app-server daemon update --from-cli --yes`。
   這個指令把 CLI 的套件複製給 daemon，並且釘住這個版本。

第 3 步會重啟 daemon。正在跑的 codex session 最多等 60 秒，然後被中斷。
新機器還沒有 daemon 時，第 3 步會跳過。第一次啟動 daemon 時，daemon 會複製 CLI 的套件。

不要執行不帶 `--from-cli` 的 `codex app-server daemon update`。這個指令會拔掉版本釘子，
並且讓 daemon 換成最新的正式版。下次 apply 會再把 daemon 釘回 CLI 的版本。

實測（codex-cli 0.161.0，2026-10-08，WSL）：`--from-cli` 執行後，daemon 的更新程式
（`app-server daemon pid-update-loop`）停止，`releases/` 下的套件名稱變成 `local-<hash>`。

已知問題（2026-10-09，Windows）：`codex app-server daemon start` 失敗，訊息是
「socket directory is not private to the current user」。這台機器的 daemon 起不來，
所以第 3 步一直跳過。官方 installer 版的第 3 步只在 bash 上用 stub 測過。

## 使用方式

```bash
# 預設設定
codex

# 快速模式
codex -p quick

# 深度模式
codex -p deep

# 研究模式
codex -p research
```

## 與 Claude Code 的差異

以下能力不建議直接一比一照搬：

- Claude slash commands：改用 Codex skills / review mode / subagents
- Claude plugins：依能力改用 Codex 原生 plugins 或 MCP，不直接搬用 Claude plugin 設定
- Claude 全域 prompt 覆寫：改用 `instructions` + `AGENTS.md` + skills

這樣的好處是比較貼近 Codex 官方設計，也比較不容易在版本升級後失效。
