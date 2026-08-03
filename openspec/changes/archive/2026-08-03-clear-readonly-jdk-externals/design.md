## Context

`chezmoi apply` 在 Windows 上會被 external archive **自己寫出來的唯讀檔案**擋住。
Temurin zip 的少數 entry 帶唯讀權限位,chezmoi 解壓時映射成 Windows 的 `ReadOnly`
檔案屬性;下次升版覆寫同一路徑時,Windows 以 `Access is denied` 拒絕 —— 與 ACL 無關
(使用者持有 FullControl),與檔案鎖也無關(失敗當下沒有任何 java 程序)。

現況(2026-08-03 該機實測):

| 位置 | 檔案數 | ReadOnly |
|---|---:|---:|
| `.local/opt/jdk-8` | 446 | 15 |
| `.local/opt/jdk-11` | 504 | 0 |
| `.local/opt/jdk-17` | 492 | **2** |
| `.local/opt/jdk-21` | 490 | **2** |
| `.local/opt/jdk-25` | 431 | 0 |
| `.local/opt/maven`、`jdtls`、`.local/share/vim` | 2706 | 0 |

唯讀檔集中在 JDK:jdk-17/21 是 `bin/server/classes.jsa`、`classes_nocoops.jsa`(CDS
archive);jdk-8 是 `LICENSE`、`jre/lib/cmm/*.pf`、`jre/lib/management/*.template` 等 15 支。
jdk-8 目前 pin 與機器相符所以沒被觸發,下次升版就會踩。

約束:

- 上游不打算在 apply 期間暫時解除唯讀([chezmoi#3441](https://github.com/twpayne/chezmoi/issues/3441)),
  官方建議 `before_`/`after_` 腳本自理。機器上是 v2.72.0,升 chezmoi 解決不了。
- chezmoi 依 **target path 字典序**處理 target,且**沒有 skip-on-error**。任何一項失敗,
  排在它之後的 target 全部靜默落空。
- `chezmoi status` 在該機要 **31 秒**(externals 底下約 2400 個檔案要 hash),
  不能掛在 shell 啟動路徑上。

## Goals / Non-Goals

**Goals:**

- 讓 JDK external 的唯讀檔案不再阻塞 apply,且對五個 JDK 一體適用(含目前未觸發的 jdk-8)。
- 讓「apply 中止 → 後半段 target 靜默落空」在發生當下對使用者可見。
- 正常(無版本異動)的 apply 不因這次修改變慢。

**Non-Goals:**

- 不改 `.chezmoiexternal.toml` 的 JDK pin 或 external 型別。churn 是真實待升級,不是 bug。
- 不處理 CDS archive 的語意正確性(舊 jsa 對不上新 jvm.dll 時 JVM 自己會停用 CDS)。
- 不做通用的「所有 external 唯讀檔案掃描」。目前只有 JDK 有此現象,擴大掃描範圍等出現第二個案例再說。
- 不改 chezmoi 本身的行為或包裝 chezmoi 執行檔(PATH shim)。

## Decisions

### D1: 用 `run_onchange_before_` 清屬性,而非 `.chezmoiignore` 排除

<!-- evergreen-candidate -->
external archive 若寫出唯讀檔案,清屬性的責任在 dotfiles 這側 —— 這是上游明確不管的區域。

選項比較:

| 方案 | 取捨 |
|---|---|
| **`run_onchange_before_` 清屬性(採用)** | 上游建議的做法;一次涵蓋全部 5 個 JDK 的所有唯讀檔,含尚未觸發的 jdk-8 那 15 支;唯讀檔仍會被正確重新寫出 |
| `.chezmoiignore` 排除 `*.jsa` | 需先驗證 ignore 是否作用於 external 解壓內容(未證實);只蓋 CDS archive,解不掉 jdk-8 的 15 支;舊 jsa 留在磁碟上與新 jvm.dll 版本不符 |
| `run_before_`(每次 apply 都跑) | 最不會漏,但每次 apply 多付一次約 2400 檔的遞迴掃描 |

採 `run_onchange_before_` 而非 `run_before_`:onchange 的 hash key 嵌入五個 JDK 版本 pin,
**版本一變才重跑**,而版本變動正是唯一會發生覆寫的時機。正常 apply 零成本。

### D2: 清除範圍限定 `~/.local/opt/jdk-*`

範圍與 onchange key 必須耦合:key 是 JDK 版本 pin,清除範圍就只能是 JDK 目錄 —— 若把範圍
放大到整個 `~/.local/opt`,maven 或 jdtls 升版時 key 不變、腳本不跑,反而形成假的安全感。
實測 maven/jdtls/vim 的唯讀檔數為 0,現在放大也沒有收益。

### D3: 中止可見化用 shell function wrapper,不用定期 `chezmoi status`

handoff 原本設想的「在 `95-dotfiles-update.ps1` 附近加待處理筆數提示」被實測否決:
`chezmoi status` 要 31 秒,即使每日只跑一次也會讓一天中第一個 shell 卡半分鐘。

改成:包一層 `chezmoi` shell function,只在 `apply` / `update` 子命令**非零退出**時,
印出一段說明(字典序在失敗項之後的 target 未部署)並跑 `chezmoi status` 報筆數。
成本只在失敗路徑上付,happy path 完全不變。

<!-- evergreen-candidate -->
包裝既有 CLI 時採用 shell function + `command <name>` 的形式,不放 PATH shim ——
repo 內既有 `glab` wrapper(`.chezmoitemplates/shell-common/base`)已是此形狀。

三個 shell 都要有(pwsh / bash / zsh):失敗的是 Windows,但 apply 中止不分平台
(權限、磁碟、external 下載失敗都會中止),而 wrapper 本身沒有平台相依邏輯。

## Risks / Trade-offs

- **[清屬性讓唯讀檔案變可寫,削弱了 Temurin 的原意]** → 那些檔案的唯讀位是 zip 打包產物,
  不是安全邊界(同目錄其他數百個檔案都可寫,使用者對整棵樹有 FullControl)。清除後
  chezmoi 會重新寫出新版本,新版本仍帶其原有屬性。
- **[onchange key 漏掉某個會觸發覆寫的情境]** → 若 external URL 以外的原因導致重新解壓
  (例如手動刪除 external 快取),腳本不會重跑,唯讀檔可能再次擋路。屆時症狀與現在完全相同,
  且 D3 的 wrapper 會讓它立刻可見 —— 這正是 D3 存在的理由,兩者互為後盾。
- **[wrapper 只在互動 shell 生效]** → 腳本或 CI 呼叫 `chezmoi apply` 不會看到提示。可接受:
  這道防呆的對象是「人跑完就走掉」的情境。
- **[驗證需要真的下載 190MB 並升 jdk-17]** → 這是本次唯一能證明 apply 乾淨結束的手段;
  且該升級本來就是 repo 的既定狀態,不是為驗證而製造的副作用。

## Open Questions

- 無。方向已於診斷後與使用者確認。
