# User Scripts

供使用者手動執行的輔助腳本。原始碼位於 `home/dot_local/bin/`，經 chezmoi 部署到 `~/.local/bin/`。

> 新增腳本一律放 `home/dot_local/bin/`。為什麼這條分界是雙向的、放錯會怎樣，見 [`context/`](../context/index.md) 的詞彙表 `.chezmoiroot` 條目。

## 腳本清單

| 腳本 | 平台 | 說明 | 呼叫方式 |
|------|------|------|----------|
| `scoop-interactive-update.ps1` | Windows | 互動式更新 scoop 套件 | `scoopupdate` alias |
| `switch-pwsh-to-msi.ps1` | Windows | 將 Microsoft Store（MSIX）版 PowerShell 7 換成官方 MSI 版 | 手動執行，需系統管理員權限 |
| `sdkupdate` | Linux/WSL、macOS | 互動式更新 SDKMAN 套件（JDK、Maven、Gradle…） | `sdkupdate`（`~/.local/bin` 已在 PATH，不需 alias） |
| `media-fetch` | Linux/WSL、macOS | 把一支線上影片（YouTube、Facebook 或其他 yt-dlp 支援的站）存成影片檔、縮圖、手寫字幕與完整 metadata | `media-fetch <url>` |
| `media-transcribe` | Linux/WSL、macOS | 讀 `media-fetch` 存好的資料夾，產出逐字稿。不連網 | `media-transcribe <資料夾>` |
| `youtube-api` | Linux/WSL、macOS | 用 YouTube Data API v3 操作自己的帳號：列播放清單、把影片加進播放清單，或任意一個 API 呼叫 | `youtube-api playlist-add <清單名或 id> <影片網址或 id>`；第一次要先 `youtube-api auth` |
| `spotify-api` | Linux/WSL、macOS | 用 Spotify Web API 操作自己的帳號：列歌單、列歌單裡的歌，或任意一個 API 呼叫 | `spotify-api items <歌單名或 id>`；第一次要先 `spotify-api auth` |
| `agent-mux` | Linux/WSL（Windows、macOS 未驗證） | 在 herdr 或 Ghostex 裡開一個 agent、送 prompt、等它結束、關掉。`review-cross-model` 用它，所以 skill 本文不寫任何多工器指令 | `agent-mux --help`；一般不手動呼叫 |
| `mermaid-ascii` | 全平台（Windows 走 Git Bash） | 把 Mermaid 轉成框線字元的純文字圖，給畫不出 Mermaid 的地方用（Slack、Mermaid 外掛壞掉的 Confluence） | `mermaid-ascii [options] <file>` 或從 stdin 讀；Confluence 要加 `--ascii` |

## 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| [Scoop](https://scoop.sh/) | `scoop-interactive-update.ps1` | 僅 Windows |
| [SDKMAN!](https://sdkman.io/) | `sdkupdate` | 僅 Unix；SDKMAN 不支援 Windows 原生 |
| [uv](https://docs.astral.sh/uv/) | `media-fetch`、`media-transcribe` | 透過 `uvx` 取用 yt-dlp 與 whisper，不裝進系統 |
| ffmpeg | `media-fetch` | 合併影音軌、`--no-video` 時轉出 mp3 |
| Node + npm | `mermaid-ascii` | 第一次執行時把 `beautiful-mermaid` 裝到 `~/.local/share/beautiful-mermaid/<版本>/` |
| python3（只用標準庫）| `youtube-api`、`spotify-api` | 不用 `uv`，也不裝 Google 的 client library |
| jq | `agent-mux` | 解析 herdr 與 Ghostex 回的 JSON |
| JS runtime（deno / node / bun）| `media-fetch` | YouTube 的 token 檢查需要；缺了字幕端點會回 429 |

## `sdkupdate` 設計備忘

SDKMAN 沒有 scoop `update` 那種「原地升級」指令：`sdk upgrade` 只印出落後清單不動手，
`sdk install <candidate>` 則直接跳到全域最新版。`sdkupdate` 補的就是中間那一段。

**只在同一條版本線內升級。** 版本線 = major 版號 + flavor，flavor 是把版本字串裡所有
數字段抹掉後剩下的字面標記（`-tem`、`-zulu`、`-fx…-librca`、`crac-zulu`、`-rc-`）。
所以 `25.0.1-tem → 25.0.4-tem` 會提示，而 25→26、tem→zulu、Maven `3.9.16 → 4.0.0-rc-6`
都不會。pre-release 是免費附帶擋掉的：`4.0.0-rc-6` 的 flavor 是 `-rc-`，配不上
`3.9.16` 的空 flavor。跨大版本是人工決定，用 `sdk install <candidate> <version>`。

**已知的保守誤判。** 廠商在同一個 major 內改版號格式時，flavor 會跟著變，該筆就不會
被提示。目前已知 GraalVM CE 的 `25.0.2-graalce`（flavor `-graalce`）配不上
`25.3.4+1.r25-graalce`（flavor `.r-graalce`）。寧可漏報也不要把不同產品線當成升級目標。

### 三個踩過的坑

- **不能用 `set -u`。** sdkman 的內部函式會參照未設定的變數。在 non-interactive
  shell 下 `set -u` 不是回傳錯誤，而是**立刻終止整個 script** —— 症狀是 `sdk update`
  之後無聲收尾，沒有任何錯誤訊息。
- **詢問迴圈必須從 fd 3 讀清單。** 寫成 `done <<<"$updates"` 的話，迴圈內的
  `read -p` 會接著從同一份 here-string 取資料，把還沒問到的更新項當成使用者的答案
  吃掉：六項只會問三項，而且答案全部錯位。
- **升級完要還原預設版本。** 本機 `sdkman_auto_answer=true`，`sdk install` 會靜默把
  新裝的設成預設。升一個舊分支的 JDK 就會把 `java current` 從 25 換成 8。script 在
  開始前記下每個候選的預設版本，全部處理完再設回去；若預設本身被升級，則指向新版。

### 相容性

以 macOS 內建的 bash 3.2 為下限：不使用 associative array（`declare -A` 需要 bash 4），
也不使用 `find -printf`（GNU 擴充，BSD find 沒有）。

## `media-fetch` / `media-transcribe` 設計備忘

兩支腳本共用一個資料夾。一支影片一個資料夾，路徑是 `<base>/<上傳日期>-<video id>/`。
base 依序取 `--base-dir`、`$MEDIA_BASE`、`~/.agent/media`。

- `media-fetch <url>` 負責所有網路動作。它存影片、縮圖、手寫字幕與 metadata，然後結束。
  只想保留影片時，跑這一支就好。
- `media-transcribe <資料夾>` 只讀資料夾裡的檔案，不連網。所以可以晚點再跑，也可以換
  模型重跑，都不會重新下載。

2026-10-12 以前這是一支 `yt-transcribe`，下載與轉文字綁在一起。拆開有兩個理由：
有些影片只要保留、不要逐字稿；之後要支援更多來源，下載那一半會一直長，轉文字那一半
不該跟著動。

`media-transcribe` **不做摘要**。它只量逐字稿長度，在 manifest 印出建議的模型級別，
然後結束。摘要交給呼叫者，因為模型選擇是呼叫者的成本決定，不是這支腳本的事。

### 產物

| 檔案 | 誰寫的 | 內容 |
|------|--------|------|
| `video.mp4` | fetch | 影片檔，最高畫質。`--no-video` 可略過 |
| `audio.mp3` | fetch | 只有 `--no-video` 時才有。有影片檔時，whisper 直接從 `video.mp4` 解出音軌 |
| `subs.<語言>.srt` 或 `.vtt` | fetch | 上傳者手寫的字幕，只在有的時候存 |
| `thumbnail.<原生格式>` | fetch | 縮圖 |
| `metadata.json` | fetch | yt-dlp 回報的原始 metadata，一個欄位都不刪 |
| `metadata.md` | fetch | 同上的可讀版：frontmatter 放常用欄位，body 放章節與影片說明 |
| `transcript.txt` | transcribe | 純文字逐字稿，摘要就讀這份 |
| `transcript.srt` 等 | transcribe | 帶時間戳的版本 |

`transcript_source` 是 `subtitles:<語言>` 或 `whisper:<模型>`。2026-10-12 以前的
資料夾寫的是 `youtube-subtitles:<語言>`，意思相同。

### 四個刻意的決定

- **不使用自動字幕。** YouTube 的自動字幕是滾動視窗格式：同一句話會在連續兩三個 cue
  裡重複出現，內部還夾著逐字時間標記。攤平成散文要真的做去重，而且結果仍然比
  whisper 從音檔轉出來的差。所以只用上傳者手寫的字幕；判斷來源是 `metadata.json`
  已經分開的 `subtitles`（手寫）與 `automatic_captions`（自動）兩個欄位，不多打一次網路。
- **metadata 照抓照留。** 不篩欄位。現在挑掉的欄位，就是以後想問卻問不到的答案。
  代價是檔案可能到十幾 MB，因為 `--print-json` 會帶上所有格式與字幕軌清單。
- **縮圖不轉檔。** 不加 `--convert-thumbnails`：轉檔是重新編碼，存下來的就不再是
  網站實際給的那個檔。原生格式通常是 `.webp`。
- **字幕的貢獻者掛名要濾掉。** TED 這類社群翻譯會把 `Translator:` / `Reviewer:`
  放在第一個 cue 裡。那不是講出來的話，留著會污染摘要。

### 三個踩過的坑

- **`yt-dlp` 要夠新，而且要有 JS runtime。** Ubuntu 套件庫的版本停在 2022，對現在的
  YouTube 直接失敗。改用 `uvx` 取最新版。即使版本新，少了 JS runtime 仍會在字幕
  端點吃到 `HTTP 429`；腳本會自動找 deno / node / bun 並接上。
- **`--convert-subs srt` 不保證產出 `.srt`。** 只找 `.srt` 的話，字幕明明抓到了也會
  被判定失敗而白跑一次 whisper。收檔要同時接受 `.srt` 與 `.vtt`。
- **沒有人聲的短片，whisper 會編出一句話。** 只有配樂的 Facebook reel 轉出來是
  `Thanks for watching!`。這是 whisper 的已知幻覺，不是腳本壞了。逐字稿只有一兩句時，
  先懷疑影片根本沒人說話。

## `mermaid-ascii` 設計備忘

- **為什麼不全域安裝。** `beautiful-mermaid` 只是函式庫，沒有 CLI。全域裝了也沒有指令可以叫，
  所以 `npm_install` 的守衛用不上。腳本改成在第一次執行時，把套件裝進自己的目錄。
  版本寫死在腳本的 `VERSION`；要升級就改這個值。
- **標籤只能用 ASCII。** 函式庫把一個中文字算成一格寬，但終端機會畫成兩格寬，所以框線會歪。
  上游 issue：lukilabs/beautiful-mermaid#119、#122。寫法是：圖上的標籤用英文；概念太長就標
  `(1)`、`(2)`，再在圖下面用中文解釋。
- **標號用 `(1)`，不用 `[1]`。** `A[Auth [1]]` 會被截成 `Auth [1`，加引號也一樣。
- **Confluence 要加 `--ascii`。** Confluence code block 的字型畫框線字元（`┌─┐`）時寬度不固定，
  框線會對不齊。`--ascii` 改用 `+`、`-`、`|` 來畫。
- **選項跟函式庫一對一。** `--ascii`、`--padding-x`、`--padding-y`、`--box-border-padding`、
  `--color-mode`、`--theme <json>` 直接對應 `renderMermaidASCII` 的選項，說明寫在腳本開頭。
  圖太寬時，先把 `flowchart LR` 改成 `flowchart TD`；還是太寬，再調小 `--padding-x`。
- **第一行要單獨寫圖的類型。** `graph LR; A --> B` 這種寫在同一行的格式會報錯；要寫成
  `graph LR` 再換行。

## `youtube-api` 設計備忘

2026-10-16 加入。需求是讓 agent 把影片存進使用者自己的播放清單，而且以後還會做
其他帳號操作。

### 為什麼用 API，不用瀏覽器

有兩個候選：

- **A. YouTube Data API v3**（採用）。要先在 Google Cloud 建一次專案和 OAuth client。
  之後每次呼叫都不用登入，任何平台都能跑。
- **B. 用 `wsl-chrome-cdp` 操作已登入的 Chrome**（不採用）。每次都要按 UAC、登入
  Google，而且只能在 WSL 用。只做一次的事才划算。

使用者說「以後常常做，也不只這一種事」，所以選 A。B 只剩一個用途：「稍後觀看」
（Watch later）。API 不能寫入這個清單。

### 三個刻意的決定

- **只用 Python 標準庫。** OAuth 只需要一個 loopback 伺服器加兩次 POST，大約五十行。
  Google 的 client library 會多拉一串依賴，換來的只是少寫這五十行。
- **scope 用整個帳號的 `auth/youtube`。** 窄的 scope 每多一種呼叫就要重新同意一次。
  使用者已經說會做別的事，所以一次拿足。
- **留一個 `call` 子指令。** 新的操作先用 `youtube-api call <METHOD> <resource> k=v ...`
  直接打 API。同一種操作常用了，才包成子指令。

### 檔案與設定

憑證放 `${XDG_CONFIG_HOME:-~/.config}/youtube-api/`，權限 600，不進任何 repo：

| 檔案 | 內容 |
|------|------|
| `client_secret.json` | 從 Google Cloud 下載的 Desktop app OAuth client |
| `token.json` | `youtube-api auth` 寫的 refresh token |

換新機器時，把 `client_secret.json` 複製過去，再跑一次 `youtube-api auth`。
Google 對 Desktop app 的 client secret 不當作機密，但它仍然不該進公開 repo。

### 兩個坑

- **OAuth app 停在「Testing」，refresh token 七天就失效。** Google Auth Platform 的
  Audience 頁要按 Publish app，改成「In production」。按鈕要先在 Branding 頁填好首頁與
  隱私權政策網址才會亮；填 GitHub 網址時，還要把 `github.com` 加進 Authorized domains。
  沒驗證的 app 登入時會出現
  「Google hasn't verified this app」，按 Advanced 再繼續即可。這個 app 只有自己用，
  不會碰到一百人的上限。
- **WSL 裡的 Python 開不了瀏覽器。** `webbrowser` 找不到可執行的瀏覽器，所以
  `youtube-api auth` 會把登入網址印到 stderr，要自己點。Windows 瀏覽器連得到 WSL 的
  `127.0.0.1`，所以登入完成後會自動導回腳本，不用貼網址。

## `spotify-api` 設計備忘

2026-10-27 加入。需求是整理使用者自己的 Spotify 歌單。結構照抄 `youtube-api`：
只用 Python 標準庫，留一個 `call` 子指令，憑證不進任何 repo。下面只寫不一樣的地方。

### 前提：帳號要有 Premium

2026-02 起，Development Mode 的 app 要求 app 擁有者有 Premium。Premium 停掉，app
就停；重新訂閱後恢復。見 Spotify 的
[February 2026 migration guide](https://developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide)。

同一份指南的其他限制：

- 歌單內容只讀得到自己建的、或一起編輯的歌單。別人的歌單只回 metadata。
- 端點改名：`/playlists/{id}/tracks` 改成 `/playlists/{id}/items`；回應裡的 `tracks`
  改成 `items`，`track` 改成 `item`。網路上的舊範例大多還是舊名。

### 檔案與設定

憑證放 `${XDG_CONFIG_HOME:-~/.config}/spotify-api/`，不進任何 repo：

| 檔案 | 內容 |
|------|------|
| `client_id` | developer.spotify.com 上 app 的 Client ID，一行 |
| `token.json` | `spotify-api auth` 寫的 refresh token，權限 600 |

用 PKCE 登入，所以不需要 client secret。換新機器時，把 `client_id` 複製過去，再跑一次
`spotify-api auth`。

app 的設定：Redirect URI 填 `http://127.0.0.1:8765/callback`，API 勾 Web API。

### 兩個坑

- **Redirect URI 不能用 `localhost`。** Spotify 只接受 `127.0.0.1` 或 `[::1]`。
  port 寫死成 8765，因為登記的網址要完全一樣。8765 被占用時 `auth` 會失敗。
- **refresh token 可能會換新。** 換新時，腳本會把新的寫回 `token.json`。

## `agent-mux` 設計備忘

2026-10-28 加入。`review-cross-model` 要在另一個終端開一個不同 kind 的 agent。以前它直接下
herdr 指令，所以在 Ghostex 裡每次都退化。現在 skill 只呼叫 `agent-mux`，兩個多工器的差異
都在腳本裡。

### 動詞

| 動詞 | 做什麼 | stdout |
|------|--------|--------|
| `detect` | 依序試 herdr、Ghostex | `herdr` 或 `ghostex`；都不行就在 stderr 列出兩邊的原因 |
| `start <name> <kind> <repo> [-- 參數]` | 開終端、啟動 agent、把終端識別碼寫進 `~/.local/state/agent-mux/<name>.env` | 後端名稱 |
| `alive <name>` | agent 還在不在 | `alive` / `gone` / `unknown`（多工器沒回應，exit 2） |
| `state <name>` | 目前狀態 | `idle` `working` `blocked` `done` `unknown` `gone` |
| `prompt <name> <檔案> [--timeout 秒]` | 先確認還活著，再送出並等到收斂 | `idle` `done` `unknown`（exit 0）；`blocked` `timeout` `gone` `failed`（exit 1） |
| `classify-read <name>` | 讀一次畫面，只用來分類失敗 | 畫面文字 |
| `exit <name> <結束指令>` | 一律先送 Escape，再送結束指令，最多等 10 秒 | `exited` / `running` / `unknown` |
| `close <name>` | 關掉 `start` 開的終端，再從多工器的清單確認它不在了。herdr 用 terminal id 找 pane，因為 pane id 在 pane move 後會變 | `closed` |

### 偵測不能只看環境變數

每個後端都要兩個條件：表示「正在裡面」的環境變數（`HERDR_ENV=1`、`GHOSTEX_SESSION_ID`），
**加上**一個唯讀指令成功（`herdr agent list`、`ghostex agents list --json`）。

原因是 Codex 的 sandbox。sandbox 裡 `HERDR_ENV=1` 還在，但 unix socket 被當成網路，
每個 herdr 指令都失敗。2026-10-28 在 `codex sandbox` 裡實測：

```
agent-mux: no agent multiplexer available -- herdr: herdr is set but unreachable:
Error: Os { code: 1, kind: PermissionDenied, ... }; Ghostex: Ghostex is set but
unreachable: gxserver did not answer ... Could not connect to local gxserver ...
```

### Ghostex 的對應做法

Ghostex 沒有 split pane，也沒有 `--wait`。對應方式：

- **終端**：在 repo 所屬的 Ghostex project 開一個新 session。repo 是 linked worktree 時，
  用 git common directory 找到它的 project，session 的 cwd 設成 worktree。找不到 project 時
  `start` 直接失敗，不呼叫 `add-project`，因為那會改到 sidebar。
- **啟動參數**：`create-agent` 不收任意參數，所以改用
  `create-session --input "exec <command> <參數>" --start`。`<command>` 取自
  `ghostex agents types`。Ghostex 照樣認得出裡面的 agent（`agentId` 會變成 `codex`）。
- **存活**：`exec` 讓 agent 結束時終端也結束，所以看 `sessions --json --full` 的
  `providerSessionState` 是不是 `exists`。不能看 `activity`：codex 退出後它還是 `idle`。
  `providerSessionState` 也會落後：終端結束後它還讀作 `exists` 大約 30 秒。所以它說
  `exists` 時，再用 `read-text --lines 1 --json` 問終端本身；回 `does not exist` 就是不在了。
- **等待**：每 2 秒輪詢。看到 `working` 之後的第一個非 `working` 狀態就算收斂；送出 10 秒
  後還沒看到 `working`，第一個非 `working` 狀態也算。
- **`attention` 有兩個意思**：等權限，或做完了但沒人看過。用 agent 自己回報的
  `programStatus.state`（`blocked` / `done`）分開。

### 踩過的坑

- **Codex 的更新提示會吃掉 Enter。** 有新版時，codex 啟動會先跳更新提示。這時 Ghostex
  回報 `idle`，`agents send` 會被拒（訊息寫 `Answer it in chat before sending`），
  所以 `prompt` 回 `blocked`。更糟的是 `/exit` 加 Enter 會選中「Update now」。
  驗證時真的發生一次，codex 從 0.164.0 升到 0.165.0。herdr 把這種對話框回報成 `done` 或
  `idle`，所以兩個後端的 `exit` 都一律先送 Escape。
- **查詢失敗不等於 agent 不在了。** gxserver 短暫沒回應時，`alive` 回 `unknown`，
  `prompt` 回 `failed`，`exit` 不送任何按鍵。只有查詢成功、且清單裡沒有它，才算 `gone`。
- **`jq -e` 讀到空輸入會回 0。** herdr 出錯時把 JSON 印到 stderr，stdout 是空的。
  腳本用 `jtest` 包一層，空輸入一律當 false。

### 驗證紀錄（2026-10-28，WSL2）

兩個後端都用 `codex`（`--sandbox workspace-write --ask-for-approval never`）跑完整一輪：
`detect` → `start` → `prompt`（要它寫一個檔，檔案內容確認）→ `exit` → `alive` 回 `gone`
→ 對已退出的 agent `prompt` 回 `gone` 且沒有送字 → `close` → 確認清單裡沒有它。
另外各跑一次 `--sandbox read-only --ask-for-approval on-request`，`prompt` 回 `blocked`。

| 後端 | 版本 | 環境 |
|------|------|------|
| herdr | 0.9.5 | 獨立的 named session（`herdr --session <名字> server`），用完刪掉，不碰預設 session |
| Ghostex | 10.31.0 | WSL backend，dotfiles project |

Windows 原生與 macOS 沒有驗證。

