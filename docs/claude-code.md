# Claude Code 設定

Claude Code 相關的個人設定檔案。

> 本文件記載操作步驟、故障排除與各能力的檔案方位。跨 change 反覆適用的判斷依據(為什麼這樣設計)在 [`context/`](../context/index.md);可驗收的行為契約在 `openspec/specs/`。

## 目錄結構

```
tools/statusline/           # 自訂狀態列程式
    statusline.go

dot_claude/                 # ~/.claude/ 設定（chezmoi 管理）
├── CLAUDE.md               # 全域指令
├── commands/               # Commands（非 exact_）
│   ├── git/                # Git 操作簡寫指令
│   └── code/               # Code Review 指令
├── skills/                 # 自家 discipline skills（非 exact_）
├── output-styles/          # Output styles（非 exact_）
├── hooks/                  # Hook 腳本
└── exact_agents/           # Agents（exact_：自動清理移除的檔案）——只有 reviewer 一個
```

`commands/`、`skills/` 與 `output-styles/` 刻意**不用** `exact_` 前綴——這幾個目錄天生會有 plugin 寫入的、機器專屬的、或實驗中的檔案（本機實測即有 3 個未受管理的 command）。`exact_agents/` 則是 chezmoi 獨佔，用 `exact_` 才對。

注意 `exact_` 是**單層**語意：`exact_agents/` 只管 `~/.claude/agents/` 的直接子項。底下若加子目錄，子目錄本身也要帶 `exact_`，否則其中被刪除的檔案永遠不會被修剪，而且是靜默的——apply 退出碼 0、`chezmoi diff` 空白、`chezmoi status` 也不列出。

因此退役一個 command/skill/output style 時，必須在 `home/.chezmoiremove` 點名該路徑，移除才會傳播到每台機器。

## Global Instructions (CLAUDE.md)

全域指令檔，設定 Claude Code 的預設行為。

### 預設工作流程

安裝後，Claude Code 在收到實作需求時會先詢問是否要使用 **OpenSpec** 流程
（Small / Large / Skip）。流程與紀律全部由自家 cross-tool skills 提供
（chezmoi shared-body + per-tool name-map，Claude / Codex 同一份身體）：

| Skill | 角色 |
|-------|------|
| `dev-workflow` | Orchestrator — 流程選擇、workspace 隔離、OpenSpec 生命週期 |
| `grill` | Large 流程前端 — 一次一題訪談，共識確認前不動工；結論直接進 openspec artifacts |
| `tdd` | 實作紀律 — 只在預先同意的 seam 測試、red before green、垂直切片 |
| `diagnose` | Bug 進入點 — 先建 feedback loop 才准提假設；根因餵進 proposal 的 Why |
| `verify-done` | 完工前驗證 — 證據先於宣稱 |
| `worktree` | 隔離 workspace 建立（normal / bare+worktree 雙架構） |
| `finish-branch` | 分支收尾 — merge/PR/處置,雙架構原生支援 |

瑣碎任務（改 typo、一行修改）會自動跳過詢問。

設計討論的結論不寫獨立文件 — `grill` 直接分流進
`openspec/changes/<change>/` 的 design.md / proposal.md / spec deltas。
（歷史脈絡:舊流程用 superpowers `brainstorming`/`writing-plans`,需要把
design doc 改道到 `~/.local/share/superpowers/<repo>/`;該機制已隨
rework-dev-workflow-skills change 退役。superpowers plugin 已於
remove-superpowers-plugin change 移除 —— 已驗證 episodic-memory 不依賴它
(自帶 hooks、來自不同 marketplace),流程紀律全改由 `~/.claude/skills/` 自家 skills 提供。
該次移除只停止安裝、uninstall 靠手動,已套用過的機器因此留著 plugin;
retire-superpowers-plugin-cleanup change 改由 `install-03-claude-config`
主動 uninstall 並清 cache,移除才隨 apply 收斂到每台機器。)

### 外部 skill：herdr

上面那張表都是自家寫的。目前唯一一份**向上游同步**的 skill 是 `herdr` ——
[herdr](https://herdr.dev/) 是專為 coding agent 設計的終端多工器（workspace / tab / pane，
會辨識 pane 裡跑的是哪個 agent 及其 idle/working/blocked/done 狀態），
它附的 skill 讓 agent 透過 CLI 與 unix socket 反過來操作 herdr 自己：開 pane、
起另一個 agent、送 prompt、等它做完、讀回輸出。派工給 Codex 因此不必刮螢幕。

它**不走 chezmoi 檔案管理**，body 也不在 repo 裡。
`run_onchange_install-herdr-skill.sh.tmpl` 執行本機的 `herdr --skill`（v0.8.0 新增，
印出該顆 binary 內建的 skill），驗過再寫進 `~/.claude/skills/herdr/` 與
`~/.codex/skills/herdr/`。**完全不碰網路。**

| 項目 | 值 |
|------|-----|
| 來源 | 本機 binary 的 `herdr --skill` |
| 版本來源 | 本機 binary，不是 repo 裡的 pin |
| 安裝者 | `home/run_onchange_install-herdr-skill.sh.tmpl` |
| 部署 | `.claude/skills/herdr/`、`.codex/skills/herdr/` |

三個設計選擇，都有具體理由：

1. **跟本機 binary 對齊，而不是釘在 repo。** herdr 會自己更新（`herdr update`、
   stable/preview channel），repo 這端釘任何版本都只是猜。skill 的內容是 CLI
   語法教學，跟 binary 對不上就會教 agent 用不存在的指令，而且不會報錯。

2. **從 binary 取，而不是從 GitHub 抓。** 早期版本讀 `herdr --version` 再去組
   `raw.githubusercontent.com/<org>/herdr/v<版本>/<路徑>`。那條路有三個各自獨立的
   斷點，全部實測踩過：`semverCompare` 預設**排除 prerelease**，所以 preview 版
   （`0.8.0-preview.<date>-<sha>`）會讓 `>=0.8.0` 回 false，選到 v0.8.0 搬走前的舊
   路徑；preview 的 git tag 是 `preview-<date>-<sha>`，`v<版本>` 根本組不出來，一律
   404；上游 org 還從 `ogulcancelik` 改名 `herdrdev`（目前靠 GitHub redirect 續命）。
   `herdr --skill` 讓「skill 對得上 binary」從推導變成結構保證，三個斷點一次消失。

3. **用腳本而不是 `.chezmoiexternal.toml`。** external 抓不到檔案時 chezmoi
   整個指令 exit 1 中止，字典序排在後面的 target 全部靜默落空（見 README 的
   Troubleshooting）。腳本能失敗軟著陸：`herdr --skill` 失敗（例如 binary 舊於
   0.8.0，沒有這個 flag）或內容驗不過，就保留現有檔案、印 `!!` 警告、正常結束。

4. **平台判斷用「有沒有這個 binary」，不用 OS。** `lookPath "herdr"` 失敗時整支
   腳本渲染成空字串，沒裝 herdr 的機器自動不適用，不需要 `.chezmoiignore` 條件。
   ⚠️ 這條原本的註解寫著「Windows 沒有 herdr」—— 自 herdr Windows preview beta 起
   **不再成立**，裝了就會跑。Windows 的細節與陷阱見 [herdr.md](herdr.md)。

`run_onchange_` 的 key 是渲染進腳本的版本號，所以**只有本機 herdr 換版時才重跑**。
寫入前會驗 frontmatter 起始、`name: herdr`、以及 description 有加引號（Codex 的 YAML
parser 比 Claude 嚴格）——拿到半截輸出時，舊的可用版本比新的壞檔案有價值。Windows 的
`herdr.exe` 吐 CRLF，寫檔前會 `tr -d '\r'` 正規化（Unix 端是 no-op）。

代價要講清楚：**body 不在 repo 裡，上游改動不經你審閱就會生效**。這是換取
「skill 永遠對得上 binary」的代價。要改回可審閱，就是把檔案 vendored 回
`.chezmoitemplates/`，並接受版本漂移要自己盯。

skill 本身另外 gate 在 `HERDR_ENV=1`，不在 herdr pane 裡會自己拒絕執行。
它的 description 偏長，會吃 Skill Listing Budget（見下方章節）。

實測記錄與 `pane read` 的來源陷阱見 [herdr.md](herdr.md)。

### 前置需求

- **OpenSpec CLI** (`@fission-ai/openspec`) — 由 `dev-workflow` 開場執行 `~/.agent/bin/ensure-openspec.sh` 按需安裝

## Plugins

### Plugin 清單

由 `run_onchange_install-03-claude-config` 自動安裝：

| 名稱 | 來源 | 說明 |
|------|------|------|
| slack | `claude-plugins-official` | Slack 讀寫、搜尋、Block Kit |
| explanatory-output-style | `claude-plugins-official` | 教育性 ★ Insight 解說輸出模式（腳本同時取消安裝 `learning-output-style`） |
| episodic-memory | `superpowers-marketplace` | 跨 session 對話記憶 |
| elements-of-style | `superpowers-marketplace` | Strunk 寫作風格改善 |

手動安裝、未納入腳本（換機時需自行補裝）：

| 名稱 | 來源 | 說明 |
|------|------|------|
| code-review | `claude-plugins-official` | `/code-review` 指令與其自帶的 review agents（與自家 `code:review-*` 無關） |

**已退役**（腳本以 `$retiredPlugins` 資料表驅動，在每台機器上主動 `plugin uninstall` 並清除殘留 cache，使移除收斂）：

| Plugin | 退役理由 |
|--------|----------|
| superpowers | workflow skills 已由 `~/.claude/skills/` 自家 discipline skills 取代 |
| claude-md-management、context7、playwright、commit-commands、security-guidance、pyright-lsp、jdtls-lsp、claude-code-setup | 未使用 |
| code-simplifier、pr-review-toolkit | 未使用；repo 曾有同名 agent，已隨 review lens 改制退役，與這兩個 plugin 始終無關 |

> 退役一個 plugin＝往那張表加一列，**不是**把安裝那行刪掉。刪安裝行不會讓已 apply 過的機器移除它，而 `run_update-claude-plugins` 依 `enabledPlugins` 迭代，每次 apply 還會繼續更新它。

`superpowers-marketplace` 本身保留，因為 `episodic-memory` 與 `elements-of-style` 仍由它提供。

### On-demand 工具

| 名稱 | 觸發方式 | 說明 |
|------|----------|------|
| OpenSpec | `dev-workflow` 開場步驟 | 結構化變更管理，按需安裝 CLI 並初始化專案 |
| OPSX Commands | `/opsx:*` commands | OpenSpec 工作流程指令（openspec CLI 產生） |
| Git Commands | `/git:*` commands | Git 操作簡寫 |
| Code Commands | `/code:*` commands | Code Review 指令 |

### Marketplace

| 名稱 | 來源 | 說明 |
|------|------|------|
| claude-plugins-official | `anthropics/claude-plugins-official` | 內建預設 marketplace |
| superpowers-marketplace | `obra/superpowers-marketplace` | 提供 `episodic-memory` 與 `elements-of-style`；同名的 `superpowers` plugin 本身已退役 |

### 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| [Claude Code](https://claude.com/claude-code) | `claude plugin` 指令 | 必須先安裝 |
| [jq](https://jqlang.github.io/jq/) | plugin hook 腳本 | Windows: `.chezmoiexternal.toml` 自動下載至 `~/.local/bin/jq.exe`；Unix: brew / apt |
| [dos2unix](https://dos2unix.sourceforge.io/) | 修復 hook CRLF (Windows) | Windows: `.chezmoiexternal.toml` 自動下載至 `~/.local/bin` |
| [jdtls](https://github.com/eclipse-jdtls/eclipse.jdt.ls) | Java LSP server | Windows: `.chezmoiexternal.toml` 自動下載至 `~/.local/opt/jdtls`（Wave 11）；Linux: 同步腳本自動下載 |
| JDK 21+ | jdtls 執行環境 | wrapper (`~/.local/bin/jdtls`) 從 `JAVA_HOME` / `~/.local/opt/jdk-N` 選擇（Windows 經 uv-managed python 啟動 launcher） |

### Plugin Scope 管理

`enabledPlugins` 支援三個 scope：

| Scope | 檔案位置 | 用途 |
|-------|----------|------|
| User | `~/.claude/settings.json` | 每個 session 都啟用（預設此專案管理的位置） |
| Project | `<repo>/.claude/settings.json` | 只在該 repo 啟用，可 commit 給 team 共享 |
| Local | `<repo>/.claude/settings.local.json` | 只在該 repo 啟用，gitignore 不分享 |

**Plugin 本體只下載一次**到 `~/.claude/plugins/cache/`（user-level），scope 只控制可見性。user-level disable 不會刪除 cache，project-level 啟用時零下載成本。

**什麼時候用 project-level？**
- Plugin 負擔大（例如 playwright 的 27 個 MCP tools），但只在特定專案需要
- Team 共享：希望隊友進 repo 就自動啟用某些 plugin

**在 project 啟用某 plugin 的步驟**

1. 確認該 plugin 已在 user-level marketplace 註冊過（`~/.claude/settings.json` 的 `extraKnownMarketplaces` 有來源）
2. 在專案根目錄建立 `.claude/settings.json`（若沒有）
3. 加入 `enabledPlugins`：
   ```json
   {
     "enabledPlugins": {
       "playwright@claude-plugins-official": true
     }
   }
   ```
4. 若要分享給 team：`git add .claude/settings.json`；只自己用：改放 `.claude/settings.local.json`（已在 Claude Code 預設 gitignore）

參考：[Claude Code settings docs](https://code.claude.com/docs/en/settings.md)

### MCP Server 的成本與 Scope 管理

**MCP 的成本是「單份 × session 數」**，不是每台機器一份。stdio server 的語意就是一 client 一 process：
每開一個 session，每個 user-scope stdio server 都會被 spawn 一次，包含那個 session 根本用不到的。
常態同時開十幾個 session 時，這個乘數就是主要的記憶體來源。

兩個把單份成本壓下來的手段（2026-07-31 實測，數字為單一 session 的 process 數）：

| 寫法 | process 數 | 多出來的是什麼 |
|------|-----------|---------------|
| `npx -y <pkg>@latest` | 3 | `npm exec` wrapper + `sh -c` 各一層 |
| 全域安裝的 binary | 1 | — |
| `chrome-devtools-mcp` 未關 telemetry | 再 +1 | usageStatistics 預設 true，會另外 spawn watchdog |

#### 這個專案的分工：安裝歸 chezmoi，連線歸各 repo

**chezmoi 只負責基礎設施。** `run_install-02-npm-tools` 把 `chrome-devtools-mcp`、`agent-browser-mcp`
全域裝好（不走 `npx`，理由見上表），讓任何 repo 想用的時候「已經在那裡」；但
`run_onchange_install-03-claude-config` **只註冊 `codegraph` 與 `atlassian` 兩個 user-scope server**。

判準對 stdio 與 http 不一樣，因為成本不一樣：

- **stdio**：每個 session 一個 process，所以要問「**是不是每個 session 都真的會用到**」。
  codegraph 是跨檔查 symbol／caller 的通用工具，符合；瀏覽器與 codex 只有特定工作才需要，
  不符合——把它們放 user scope 等於讓每個純後端 repo 的 session 都替用不到的東西付錢。
- **http**：本機不 spawn 任何 process，上面那個乘數根本不成立。`atlassian` 因此放 user scope，
  代價接近零，換來的是任何 repo 隨時能查 Jira／Confluence 而不必逐一註冊。

#### 現成可用的 MCP 清單

以下都已經由 chezmoi 準備好，任何 repo 隨時可以接上——**不需要再裝任何東西**，
只差一行註冊指令。新 repo 想用什麼，先查這張表，不要自己 `npx` 或另外 `npm i -g`。

| server | 做什麼 | 現成程度 | binary 來源 |
|--------|--------|---------|------------|
| `codegraph` | 跨檔查 symbol／caller／callee、影響範圍 | **已在 user scope，什麼都不用做** | install-02（`@colbymchenry/codegraph`） |
| `chrome-devtools` | 驅動 Chrome：導航、抓 DOM／console／network、效能 trace | binary 已裝，待註冊 | install-02（`chrome-devtools-mcp`） |
| `agent-browser` | 較輕量的瀏覽器自動化（點擊、填表、截圖） | binary 已裝，待註冊 | install-02（`agent-browser-mcp`） |
| `codex` | 把 Codex CLI 當 MCP server，交叉詢問另一個模型 | binary 已裝，待註冊 | install-02（`@openai/codex`） |
| `atlassian` | Jira／Confluence／Compass／Teamwork Graph 讀寫 | **已在 user scope**，新機器只差 `/mcp` 完成 OAuth | 遠端 http，無需 binary |

註冊指令（在該 repo 根目錄執行，選要的貼一行）：

```sh
claude mcp add --scope project chrome-devtools \
  -e CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1 -- chrome-devtools-mcp
claude mcp add --scope project agent-browser -- agent-browser-mcp
claude mcp add --scope project codex -- codex mcp-server
```

幾個要知道的：

- `--scope project` 寫進 repo 根目錄的 `.mcp.json`，可 commit 給 team 共享；只想自己用就改
  `--scope local`（寫進 `~/.claude.json` 的該專案區段，不進版控）。
- 專案 scope 的 server 首次載入需要核准，記在 settings 的 `enabledMcpjsonServers`。
- **一律指向全域 binary，不要寫 `npx -y <pkg>@latest`**——理由見上面的 process 數表。
- `atlassian` 由 install-03 自動註冊，但**登入代不了**：新機器要自己 `/mcp` 選它完成 OAuth。
  端點細節與兩個坑見下一節。
- 換新機器時這些 binary 由 `chezmoi apply` 自動補齊；repo 裡的 `.mcp.json` 跟著 git 走，兩邊會合。

清單要新增成員時，**同時改兩處**：`run_install-02-npm-tools.{sh,ps1}.tmpl` 加安裝、這張表加一列。
只加安裝沒人知道它存在；只加表格則換機器就沒有。

#### atlassian：端點選 `/authv2`，以及兩個坑

install-03 註冊的端點是 `https://mcp.atlassian.com/v1/mcp/authv2`。它是 Atlassian 現行的正典
端點，被它取代的裸 `/v1/mcp` **少了 Compass 與 Teamwork Graph 兩組工具**（31 支 vs 39 支）——
差別不只是換 auth 協議。要預先知道某端點會給哪些權限，讀它的 metadata 就好，不必先授權再數：

```sh
curl -s https://mcp.atlassian.com/.well-known/oauth-protected-resource/v1/mcp/authv2 | jq .scopes_supported
```

舊 `/v1/mcp` 連這份 metadata 都回 `Not Found`，這本身就是它屬於舊世代的訊號。

**坑一：改完 URL 一定要重啟 Claude Code。** MCP client 把 OAuth discovery 的結果快取在 process
記憶體裡，不會因為設定檔改了就重新解析。沒重啟就跑 `/mcp`，它會拿**舊端點的** authorization
server 去授權，token 存進舊的 key，而連線時查的是新端點的 key——症狀是「Got new credentials,
but atlassian rejected them on reconnect」，log 裡會看到 `Saving tokens` 與 `No access token in
storage` 只隔 100ms。那不是 OAuth 壞掉，是兩邊在講不同的 key。重啟後一次就過。

**坑二：不要啟用 claude.ai 內建的 Atlassian Rovo connector。** 那不是另一套 server，是 Anthropic
預填的同一個 Atlassian 端點；而且它停在舊的 `/v1/mcp`（[claude-code#61288](https://github.com/anthropics/claude-code/issues/61288)
提報後被 closed as not planned）。更麻煩的是內建 connector 會**依 URL 去重、遮蔽同 URL 的自註冊
條目**——你 dotfiles 註冊的那筆會靜靜消失但行為看似正常，debug 時極易誤判。自註冊的好處正在於
升級節奏握在自己手上。

**既有機器要手動遷移。** `mcp_add_if_missing` 只比對 server 名稱，所以已經有 `atlassian` 的機器
不會被 install-03 換掉端點。手動跑一次，然後**重啟** Claude Code 並 `/mcp` 重新授權：

```sh
claude mcp remove atlassian -s user
claude mcp add atlassian -s user --transport http https://mcp.atlassian.com/v1/mcp/authv2
```

注意 `-s/--scope` 是每個子命令各自解析的，`add` 漏掉就會落在預設的 `local`（只在當前目錄生效，
且優先序 local > project > user 會遮蔽 user scope 那筆，同樣是「改了沒反應」的來源）。

#### 例外：已經在 user scope、想在特定 repo 關掉

用 `deniedMcpServers`。它**真的會讓 server 不被 spawn**，不是只把 tools 藏起來（實測 probe session 內 0 個 process）。

```json
{ "deniedMcpServers": [ { "serverName": "chrome-devtools" } ] }
```

注意兩件事：

- **它是物件陣列**（`{serverName}`／`{serverCommand}`／`{serverUrl}`），不是字串陣列。寫成字串會靜默失效。
- **deny 從所有來源聯集，且優先於 allow，因此下層無法翻案。** 寫在 `~/.claude/settings.json`
  就是全機器生效，該 repo 再加 `allowedMcpServers` 放行也沒用（實測仍是 0 個 process）。

所以 deny 是補救手段，不是設計手段：真正的解法是一開始就別把它加進 user scope。

### Skill Listing Budget（CC 2.x）

Claude Code 2.x 開始強制 `skillListingBudgetFraction`（預設 1%），超過時 skill description 會被截斷，`/doctor` 顯示警告：

> Skill listing will be truncated. N descriptions dropped (full descriptions kept for most-used skills) (X.X%/1% of context)

**Budget 是 token-based**（不是 char-based）。1% of 1M context = 10K tokens。每個啟用的 skill 的 description 都會占 budget；commands 在 default 設定下也會占（因為 model-invocable）。

#### 哪些東西占 budget

| 類型 | 預設行為 | 占 budget? |
|------|---------|------------|
| Skill | model-invocable（必須） | ✅ |
| Command 無 frontmatter flag | model-invocable | ✅ |
| Command 帶 `disable-model-invocation: true` | 只能 user 手打 `/name` | ❌ |
| Skill 帶 `user-invocable: false` | 從 `/` menu 隱藏，但仍 model-invocable | ✅（這個 flag 不省 budget） |

#### 三種應對

1. **砍重複/不用的 skill**：對於 wrapper skill（歷史例:曾有 `sp:tdd` 包 `superpowers:test-driven-development`,與現在的自家 `tdd` skill 無關）直接刪。對於 plugin 整包不用就 disable。
2. **Skill → Command + `disable-model-invocation: true`**：轉換後 description 不再進 system prompt，直接從 budget 移除。例如 `/worklog-daily`、`/worklog-team-status`。這是 budget 的機制，不是選擇的理由——哪些能力該做成 command，依 `context/` 的判斷依據決定。
3. **拉 budget**（兜底）：在 `dot_claude/modify_settings.json.sh.tmpl` 加 `.skillListingBudgetFraction = 0.02`（2%）。每 turn 多 ~5K input tokens，1M context 上完全無感。

#### 跨工具共用（Codex）skill 轉 command 的 chezmoitemplate 拆分

Codex CLI 沒有 command 概念，只有 skill。要讓「Claude 這邊轉 command 但 Codex 那邊維持 skill」，body 仍能共用 chezmoitemplate：

1. `.chezmoitemplates/skills/<name>.md` 拿掉 frontmatter，只留 markdown body
2. `dot_codex/skills/<name>/SKILL.md.tmpl` 加 skill frontmatter（`name:` + `description:`）後 `{{ template ... -}}`
3. `dot_claude/commands/<name>.md.tmpl` 加 command frontmatter（`description:`；是否加 `disable-model-invocation: true` 依 `context/principles.md` 的可逆性判準決定，**不要沿用鄰近檔案的寫法當預設**）後 `{{ template ... -}}`
4. 刪 `dot_claude/skills/<name>/`（chezmoi 不會自動清 deployed orphan，需手動 `rm -rf ~/.claude/skills/<name>`）

實例：`handoff`、`worklog-daily`、`worklog-team-status` 走這個模式（commit `7a555e8` / 2026-05-06）。

#### 字元語言對 token 的影響（次要）

Claude tokenizer 對英文較友善（~0.25 tokens/char）、對中文較不友善（~0.6-1.0 tokens/char）。同義內容英文約省 30-50% tokens。但對少量 description 來說節省 token 數通常 < 0.05% of context，遠小於拉 budget 的成本。**不建議**為了省 budget 把中文 description 強制改英文，除非寫的是長 paragraph。

### Windows 已知問題：Plugin Hook Error

Windows 上安裝的 plugin hooks（`.sh` 腳本）會因為兩個問題而失敗：

| 問題 | 原因 | 修復方式 |
|------|------|----------|
| 路徑反斜線 | `${CLAUDE_PLUGIN_ROOT}` 展開為 `C:\...`，bash 將 `\` 當跳脫字元 | 用 `cygpath` 轉換路徑 |
| CRLF 換行符 | 部分 plugin 的 `.sh` 被存為 CRLF | 用 `dos2unix` 轉為 LF |
| UTF-8 BOM | `hooks.json` 帶有 BOM (`EF BB BF`)，Claude Code 的 JSON parser 無法解析 | 移除 BOM（安裝腳本已自動處理） |

**BOM 問題細節：** PowerShell 5.x 的 `-Encoding UTF8` 會寫入帶 BOM 的 UTF-8。安裝腳本 step 11 修補 hooks.json 後，檔案會被加上 BOM，導致所有 plugin hooks 載入失敗（`JSON Parse error: Unrecognized token '﻿'`）。安裝腳本 step 13 會自動移除 BOM。Plugin 更新後需重新執行安裝腳本。

安裝腳本 `run_onchange_install-claude-plugins` 已包含自動修復步驟。如果 plugin 更新後問題復發，重新執行安裝腳本即可。

**前置需求：**
- `jq` — hook 腳本用來解析 JSON（Windows 由 `.chezmoiexternal.toml` 提供，無須手動安裝）
- `dos2unix` — 轉換換行符（Windows 由 `.chezmoiexternal.toml` 提供，無須手動安裝）

**追蹤 Issues：**
- [#21878](https://github.com/anthropics/claude-code/issues/21878) — Hook scripts fail on Windows: backslash paths
- [#22906](https://github.com/anthropics/claude-code/issues/22906) / [#22934](https://github.com/anthropics/claude-code/issues/22934) — SessionStart hook errors cause CLI freeze

待官方修復後可移除 workaround。

### episodic-memory MCP 連不上（plugin cache 不完整）

`claude mcp list` 顯示 `plugin:episodic-memory:episodic-memory - ✘ Failed to connect`。

| 項目 | 說明 |
|------|------|
| 症狀 | MCP server 啟動指令 `node .../cli/mcp-server-wrapper.js` 找不到檔案 |
| 根因 | plugin cache (`~/.claude/plugins/cache/superpowers-marketplace/episodic-memory/`) 被 Claude 內部 GC 誤刪目錄，缺 `cli/ dist/ src/ scripts/` 等，只剩 `docs/ skills/ test/`（會留下 `.orphaned_at` 標記） |
| 修復 | 重裝讓 Claude 重新 clone 完整 repo：`claude plugin uninstall episodic-memory@superpowers-marketplace` 後 `claude plugin install episodic-memory@superpowers-marketplace`（單純 install 不會修復已存在的壞 cache，需先 uninstall） |
| 首次啟動 | `cli/dist` 已隨 repo commit，但執行期依賴（better-sqlite3 等原生模組）需 `node_modules`；wrapper 首次啟動會自動 `npm install`（約 30–60 秒，含原生編譯），故第一次 health check 可能逾時顯示 failed，裝完即恢復 |

安裝腳本 `run_onchange_install-03-claude-config` 已包含 episodic-memory 安裝，新機器會自動裝；cache 損壞時手動重裝即可。

## ensure-openspec 腳本

按需安裝 OpenSpec CLI 並初始化當前專案。正典位置 `~/.agent/bin/ensure-openspec.sh`，
由 `dev-workflow` skill 的開場步驟以絕對路徑呼叫。

### 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| [Node.js](https://nodejs.org/) / npm | 安裝 OpenSpec CLI (`npm install -g`) | 支援透過 [nvm](https://github.com/nvm-sh/nvm) 載入 |

### 功能

1. 檢查 OpenSpec CLI 是否已安裝，沒有則透過 npm 安裝
2. 檢查當前專案是否已 `openspec init`，沒有則執行初始化
3. 已初始化的專案會執行 `openspec update`，並以 `--tools claude,codex,antigravity` 補齊工具

### 使用方式

`dev-workflow` 會自動執行，一般不需手動觸發。要手動跑就用絕對路徑
`~/.agent/bin/ensure-openspec.sh`。

> 曾有 `/ensure-openspec` command 包裝它，已於 prune-ensure-openspec-orphans change
> 移除：該 command 以 bare 名稱呼叫，在 WSL 下命中了 `~/.local/bin` 底下的過時副本
> （`init --tools claude`，會砍掉 codex/antigravity surface）。

## Status Line

自訂的 Claude Code 狀態列，使用 Go 編寫以獲得更好的效能。

### 顯示效果

```
[💛 Opus 4.5] 📂 project ⚡ main* | ██████░░░░ 52.8% 105.6k | 1h30m [2 sessions]
🔥 $4.00/hr │ 💰 Today: $6.83 │ ⏱ Reset: 2h 25m
MCP: ✓ context7, atlassian, playwright, chrome-devtools │ ✗ github
```

#### 第一行
- 模型名稱與 emoji（💛 Opus / 💠 Sonnet / 🌸 Haiku）
- 專案目錄名稱
- Git 分支（有未提交變更時顯示 `*`）
- Context 使用量進度條、百分比，與 `已用/上限` token 數（上限取 stdin JSON 的 `context_window.context_window_size`）
- 今日累計使用時數

#### 第二行
- Burn Rate（每小時消耗）
- 今日總花費
- Block Reset 倒數時間

#### 第三行
- MCP 伺服器狀態（顯示已連接與失敗的伺服器名稱）
- Plugin MCP server（`plugin:source:name` 格式）自動取最後一段作為顯示名稱

### 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| [Bun](https://bun.sh/) | 執行 ccusage | |
| [ccusage](https://github.com/ryoppippi/ccusage) | 費用統計 | 透過 `bunx ccusage` 自動下載執行 |
| [Claude Code](https://claude.com/claude-code) | MCP 狀態檢查 | `claude mcp list` |
| [Go](https://go.dev/) 1.18+ | **僅本地開發 statusline 時需要** | 一般使用不需要，見下方說明 |

### 安裝

> **一般使用不需要手動編譯。** `.chezmoiexternal.toml` 會依平台自動從 `statusline-latest` release
> 下載對應的 binary 到 `~/.local/bin/statusline`，`chezmoi apply` 即完成。以下步驟只在你要改
> `tools/statusline/` 的程式碼、想在本機驗證時才用得到。

#### 1. 安裝依賴（僅本地開發）

**Go：**

```bash
# Ubuntu/Debian —— 注意 apt 版本太舊不支援 GOTOOLCHAIN，
# 本 repo 的安裝腳本改用官方 tarball 裝到 ~/.local/go
sudo apt install -y golang-go

# macOS
brew install go

# Windows —— 由 .chezmoiexternal.toml 提供，安裝到 ~/.local/opt/go，無須手動安裝
```

**Bun（執行 ccusage 用）：**

```bash
# macOS/Linux
curl -fsSL https://bun.sh/install | bash

# Windows (PowerShell)
powershell -c "irm bun.sh/install.ps1 | iex"
```

安裝後重新載入 shell：
```bash
source ~/.bashrc  # 或 source ~/.zshrc
```

**ccusage（費用統計）：**

ccusage 不需要預先安裝，`bunx ccusage` 會自動下載並執行。首次執行會稍慢，之後會使用快取。

#### 2. 複製並編譯

```bash
cd tools/statusline
go build -o ~/.claude/statusline.exe .   # Windows
go build -o ~/.claude/statusline .       # macOS/Linux
```

#### 3. 設定 Claude Code

編輯 `~/.claude/settings.json`，加入 statusLine 設定：

**Windows:**
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash -c '/c/Users/<username>/.claude/statusline.exe'",
    "padding": 0
  }
}
```

> **注意（Windows）**：必須用 `bash -c '...'` 包裝，直接呼叫 `.exe` 時 Claude Code 不會透過 shell 執行，stdin 無法 pipe 進去，導致 statusline 空白。

**macOS/Linux:**
```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline",
    "padding": 0
  }
}
```

#### 4. 重啟 Claude Code

### 資料來源

2026-04-01 重構移除 ccusage CLI、JSONL 掃描與 cache 系統，所有資料改從 Claude Code 注入的 stdin JSON 直接取得（context %、token、session cost、duration、rate limits、worktree）。外部 I/O 僅剩 git 命令與進程計數。

### 平行化與 timeout

主流程用 goroutine 平行跑慢源 + 1 秒 `asyncTimeout`：

- `getGitInfo()` — 內部再分 3 個 goroutine：`git branch --show-current` / `git status --porcelain` / `git diff --shortstat`。Wall time = max(spawn) 而非 sum，Windows warm 中位數 428 ms（2026-04-24 平行化前為 1111 ms，常超時導致 branch/diff 段被吞掉）。

未在 1 秒內完成時，對應段落會以空字串呈現（不阻塞 statusline 渲染）。

### Session 追蹤

**使用時間** 由 Claude Code stdin JSON 的 `cost.total_duration_ms` 直接提供，statusline 不再自行維護心跳。

**Effort 等級** 優先取 stdin JSON 的 `effort.level`（per-session，跟著 `/effort` 即時變動）；欄位不存在時退回環境變數 `CLAUDE_EFFORT`，再退回 `~/.claude/settings.json` 的 `effortLevel` 靜態預設。

**活躍 session 數量** 曾以 `[N]` 徽章顯示在第二行，2026-09-03 移除。連同 `count_unix.go`／`count_windows.go` 與 `golang.org/x/sys` 相依一併刪除。

### 參考

樣式參考自 [Claude Code Status Line](https://jackle.pro/articles/claude-code-status-line)

## Handoff 機制

切換 session 時的無縫接續機制。由 skill、hook、statusline 三者配合：

### 組件

| 角色 | 檔案 | 觸發 |
|---|---|---|
| Command / Skill | `dot_claude/commands/handoff.md.tmpl`＋ `dot_codex/skills/handoff/`；共用 body 在 `.chezmoitemplates/skills/handoff.md` | `/handoff`、「切 session」、reminder 後確認 |
| 復原端 | `dot_claude/commands/pickup.md.tmpl` ＋ `dot_codex/skills/pickup/`；共用 body 在 `.chezmoitemplates/skills/pickup.md` | `/pickup <id>`；無參數則取最新一份 |
| 提醒 hook | `dot_claude/hooks/executable_handoff-reminder.sh` | UserPromptSubmit；context 達 40/70/90% 各提醒一次 |
| Cache writer | `tools/statusline/statusline.go` 的 `writeContextWindowCache()` | 每次 statusline 渲染 |
| 註冊 | `dot_claude/modify_settings.json.sh.tmpl` jq patch | chezmoi apply 時生效 |

### 資料流

Statusline 每次渲染寫兩份 cache（`context_window_size > 0` 時）：

- `~/.cache/claude-handoff/session-<id>.cache` — 精確匹配當前 session
- `~/.cache/claude-handoff/latest.cache` — 跨 session fallback，永不清理

Reminder hook 解析當前 context 使用率的順序：

1. `$CLAUDE_HANDOFF_CONTEXT_WINDOW` env var（debug/override 專用）
2. `session-<id>.cache`（主要）
3. `latest.cache`（跨 session fallback）
4. Model name mapping → 200000
5. Default 200000

`latest.cache` 存在的原因：新 session 的首個 prompt 在 statusline 首次重繪前就進來時，`session-<id>.cache` 尚未寫出，靠它避免誤觸發 200k fallback。

Per-session 的 `session-<id>.cache` / `reminded-*` 哨兵刻意**不清理**：檔案僅 7B、以 session-id 命名永不撞號，留著無害；過去的 SessionEnd 清理 hook 因 SessionEnd 觸發不可靠（terminal 直接關、crash 都不跑）本就會洩漏，已移除。

### 產出與共用約定

`/handoff` 的輸出：

- `~/.agent/handoffs/<repo-slug>/<YYYY-MM-DD-HHMM>__<slug>.md` — 簡短 checkpoint（≤50 行，以 references 為主，不重述既有 artifact）
- 印出該檔絕對路徑，以及可直接複製的 `/pickup <id> in <語言>` 指令（英文 session 不加後綴）

落點在 `~/.agent/` 而非 repo 內或工具專屬 dotdir。副作用是不需要動 `.gitignore` — 檔案本來就不在 repo 裡。

`repo-slug` 取 `git rev-parse --path-format=absolute --git-common-dir` 去掉最後一段，再把 `:`、`\`、`/`、`.` 全換成 `-`；與 `~/.claude/memory/<id>/` 的 auto-memory 規則同源。不用 `--show-toplevel` — 那在 bare+worktree 佈局下會依 worktree 分裂成多個目錄，彼此看不見。

`## Suggested skills` 與 `## Next steps` 是**寫入端**的硬性要求，`handoff` 寫檔前自我檢查；後者每條還要帶可驗證的成功判準。

跨 repo 交接用 `--repo <path>`，且只認使用者明講 —— agent 察覺內容屬別的 repo 可以問，但不得自行改落點。

這個目錄不只放 session state：`/arch-review` 的體檢報告也寫在這裡，靠同一套 `pickup` 契約被接手（見下節）。

### 待辦清單與封存

這個目錄同時當待辦清單用，三個指令構成一個生命週期：

- `/handoff-list` — 唯讀列出未封存項（ID、日期、一行 Task、next-step 條數）。**不推測**任何 handoff 是否完成，也不標註「可能已完成」候選
- `/pickup` — 接手；`## Next steps` 全數達成後列出逐條證據，經使用者確認才把檔案 `mv` 進 `<repo-slug>/archive/`
- 封存永遠是搬移，不是 `rm`。`pickup` 只 glob `<repo-slug>/*.md`，故 `archive/` 天然退出所有查找

刻意不與 `finish-branch` 耦合：跨 repo 交接與 `arch-review` 報告不對應任何分支，綁在一起會讓它們永遠無法封存。

### 舊路徑

`pickup` 仍會回退查找兩個 legacy 位置：`~/.local/state/handoffs/<repo-slug>/`（`~/.agent` 之前）與 `<repo>/.claude/handoffs/`（2026-05-26 之前）。新產出一律寫 `~/.agent/handoffs/`。

### 設定需求

- `jq` 必須安裝（hooks 依賴）
- `CLAUDE_HANDOFF_CONTEXT_WINDOW` env var **不要**放進 settings.json — 會破壞 cache-first 的動態性（每次都走 env 就不會讀 cache）

## Code Review（`code:review-*`）

八支指令共用一組 **lens**：`~/.agent/reference/review-lenses/` 下的純檔案，一個
檔案一個觀點。flow 指名要跑哪幾個，reviewer 自己去讀。

| Flow | Lens |
|------|------|
| `code:review-comprehensive` | 全部七個 ＋ confidence 過濾 ＋ cross-model 反駁 |
| `code:review-uncommitted` | 依變更檔案類型挑選 ＋ confidence 過濾 |
| `code:review-surgical` | correctness、design |
| `code:review-security` | security、failure-handling |
| `code:review-linus` | design（整體裁決式報告） |
| `code:review-types` | design（逐型別評分報告） |
| `code:review-spec` | 不用 lens——三個問題都相對於 OpenSpec artifact |
| `code:review-cross-model` | 不用 lens——把結論丟給別的 model 家族反駁 |

七個 lens：`correctness`、`failure-handling`、`tests`、`design`、`comments`、
`conventions`、`security`。切法的原則是**一條 finding 只屬於一個 lens**；兩個
lens 同時回報同一件事是邊界沒切好，不是互相佐證。

### 為什麼是檔案，不是 agent

agent 與 skill 的 `description` 會**預載入每個 session** 的 system prompt——模型
必須先看見才能決定要不要路由過去。只有 body 是 lazy。所以一個從沒被叫用的 agent
仍然每個 session 都在收費。

觀點內容曾經是七個 agent，約 12KB description，等於「無論今天有沒有 review 都付
費」。改成檔案後，flow 已經決定要跑哪個 lens 了，檔案可以躺在磁碟上直到那一刻。
順帶解決了另一半：Codex 沒有 agent 機制，以前拿到的是一張它派不出去的 agent 表，
真正的 lens 內容一行都沒有。現在兩邊指向同一批路徑。

### reviewer agent

`~/.claude/agents/reviewer.md` 是唯一留下的 agent，`tools: Read, Grep, Glob`。

這一行是唯讀性的**唯一**強制點。省略 `tools` 等於繼承全部工具，包含 `Write` 與
`Edit`——舊的七個 agent 全都是這樣，所以指令裡那句 "Do not modify code" 從來只是
散文。

### 守衛

`tests/review-lens-refs.test.sh` 雙向檢查：flow 指名的 lens 都存在，存在的 lens 都
有 flow 指名。後者才是關鍵——少一個 lens 第一次跑 flow 就會現形，多一個永遠不會。
另外掃描所有共用 body，確認七個退役 agent 名字沒有復活。

沒有任何東西在 render 期解析 lens 路徑，所以打錯字的 flow 會 render 成功、apply
成功，直到 review 當下才在 subagent 裡失敗。

## Arch Review（`/arch-review`）

整庫架構體檢。行為契約見 [`openspec/specs/arch-review/spec.md`](../openspec/specs/arch-review/spec.md)——它定義了跨工具部署形狀、兩階段掃描紀律、判準來源分層與降級可見性、pickup 相容的產出格式，以及「只診斷不動刀」的邊界。本節只記檔案方位與實跑經驗。

### 組件

| 角色 | 檔案 |
|---|---|
| Claude command | `dot_claude/commands/arch-review.md.tmpl` |
| Codex skill | `dot_codex/skills/arch-review/SKILL.md.tmpl` |
| 共用 body | `.chezmoitemplates/skills/arch-review.md` |

### 使用方式

預設掃整庫，可傳路徑縮限：`/arch-review src/payment`。

產出寫到 `~/.agent/handoffs/<repo-slug>/<YYYY-MM-DD-HHMM>__arch-review.md`，用 `/pickup <id>` 接手選中的候選。

### 何時該跑

刻意**不掛進 dev-workflow 或 finish-branch**。正確頻率是里程碑、或數個 change 累積之後。

**預期會有很多次「沒有候選」。** 首次實跑（`chat_setting_api`，194 檔）就是這個結果：`domain/` 完全沒 import `spring.*`、最大檔 163 行、無同名 class；唯一的訊號是 `sensitiveword` 與 `whitelistdomain` 兩條垂直線的 package 結構 1:1 對稱，但把 domain 名詞正規化後對角比對，139 行的檔案仍有 109 行不同 —— 是兩個真正不同的模型（一個以 `(scope, category)` 為粒度，一個是 default + per-BU），硬抽共用抽象反而會逼簡單的那邊揹上不需要的維度。

這正是預期行為，不是白跑：**對稱的是 package 形狀，不是邏輯**，而前者是優點。

### 維護備註

- Per-session cache（`session-<id>.cache`、`reminded-<id>-<tier>`）無自動清理機制；單檔 7B、無功能影響。真要清空可手動 `rm ~/.cache/claude-handoff/session-* ~/.cache/claude-handoff/reminded-*`（保留 `latest.cache`）。
