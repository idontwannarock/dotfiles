# User Scripts

供使用者手動執行的輔助腳本。原始碼位於 `home/dot_local/bin/`，經 chezmoi 部署到 `~/.local/bin/`。

> 新增腳本一律放 `home/dot_local/bin/`。為什麼這條分界是雙向的、放錯會怎樣，見 [`context/`](../context/index.md) 的詞彙表 `.chezmoiroot` 條目。

## 腳本清單

| 腳本 | 平台 | 說明 | 呼叫方式 |
|------|------|------|----------|
| `scoop-interactive-update.ps1` | Windows | 互動式更新 scoop 套件 | `scoopupdate` alias |
| `switch-pwsh-to-msi.ps1` | Windows | 將 Microsoft Store（MSIX）版 PowerShell 7 換成官方 MSI 版 | 手動執行，需系統管理員權限 |
| `sdkupdate` | Linux/WSL、macOS | 互動式更新 SDKMAN 套件（JDK、Maven、Gradle…） | `sdkupdate`（`~/.local/bin` 已在 PATH，不需 alias） |
| `yt-transcribe` | Linux/WSL、macOS | 把一支 YouTube 影片存成影片檔、音檔、逐字稿、縮圖與完整 metadata | `yt-transcribe <url>` |

## 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| [Scoop](https://scoop.sh/) | `scoop-interactive-update.ps1` | 僅 Windows |
| [SDKMAN!](https://sdkman.io/) | `sdkupdate` | 僅 Unix；SDKMAN 不支援 Windows 原生 |
| [uv](https://docs.astral.sh/uv/) | `yt-transcribe` | 透過 `uvx` 取用 yt-dlp 與 whisper，不裝進系統 |
| ffmpeg | `yt-transcribe` | 合併影音軌、從影片抽音軌 |
| JS runtime（deno / node / bun）| `yt-transcribe` | YouTube 的 token 檢查需要；缺了字幕端點會回 429 |

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

## `yt-transcribe` 設計備忘

一支影片產生一個資料夾，路徑是 `<base>/<上傳日期>-<video id>/`。base 依序取
`--base-dir`、`$YT_TRANSCRIBE_BASE`、`~/.agent/media`。

腳本**不做摘要**。它只量逐字稿長度，在 manifest 印出建議的模型級別，然後結束。
摘要交給呼叫者，因為模型選擇是呼叫者的成本決定，不是這支腳本的事。

### 產物

| 檔案 | 內容 |
|------|------|
| `video.mp4` | 影片檔，最高畫質。`--no-video` 可略過 |
| `audio.mp3` | 音軌。有影片檔時用 ffmpeg 從本機抽出，不重抓一次 |
| `transcript.txt` | 純文字逐字稿，摘要就讀這份 |
| `transcript.srt` 等 | 帶時間戳的版本 |
| `thumbnail.<原生格式>` | 縮圖 |
| `metadata.json` | yt-dlp 回報的原始 metadata，一個欄位都不刪 |
| `metadata.md` | 同上的可讀版：frontmatter 放常用欄位，body 放章節與影片說明 |

### 四個刻意的決定

- **不使用自動字幕。** YouTube 的自動字幕是滾動視窗格式：同一句話會在連續兩三個 cue
  裡重複出現，內部還夾著逐字時間標記。攤平成散文要真的做去重，而且結果仍然比
  whisper 從音檔轉出來的差。所以只用上傳者手寫的字幕；判斷來源是 `metadata.json`
  已經分開的 `subtitles`（手寫）與 `automatic_captions`（自動）兩個欄位，不多打一次網路。
- **metadata 照抓照留。** 不篩欄位。現在挑掉的欄位，就是以後想問卻問不到的答案。
  代價是檔案可能到十幾 MB，因為 `--print-json` 會帶上所有格式與字幕軌清單。
- **縮圖不轉檔。** 不加 `--convert-thumbnails`：轉檔是重新編碼，存下來的就不再是
  YouTube 實際給的那個檔。原生格式通常是 `.webp`。
- **字幕的貢獻者掛名要濾掉。** TED 這類社群翻譯會把 `Translator:` / `Reviewer:`
  放在第一個 cue 裡。那不是講出來的話，留著會污染摘要。

### 兩個踩過的坑

- **`yt-dlp` 要夠新，而且要有 JS runtime。** Ubuntu 套件庫的版本停在 2022，對現在的
  YouTube 直接失敗。改用 `uvx` 取最新版。即使版本新，少了 JS runtime 仍會在字幕
  端點吃到 `HTTP 429`；腳本會自動找 deno / node / bun 並接上。
- **`--convert-subs srt` 不保證產出 `.srt`。** 只找 `.srt` 的話，字幕明明抓到了也會
  被判定失敗而白跑一次 whisper。收檔要同時接受 `.srt` 與 `.vtt`。
