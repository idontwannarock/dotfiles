# User Scripts

供使用者手動執行的輔助腳本。原始碼位於 `home/dot_local/bin/`，經 chezmoi 部署到 `~/.local/bin/`。

> 新增腳本一律放 `home/dot_local/bin/`。為什麼這條分界是雙向的、放錯會怎樣，見 [`context/`](../context/index.md) 的詞彙表 `.chezmoiroot` 條目。

## 腳本清單

| 腳本 | 平台 | 說明 | 呼叫方式 |
|------|------|------|----------|
| `scoop-interactive-update.ps1` | Windows | 互動式更新 scoop 套件 | `scoopupdate` alias |
| `switch-pwsh-to-msi.ps1` | Windows | 將 Microsoft Store（MSIX）版 PowerShell 7 換成官方 MSI 版 | 手動執行，需系統管理員權限 |
| `sdkupdate` | Linux/WSL、macOS | 互動式更新 SDKMAN 套件（JDK、Maven、Gradle…） | `sdkupdate`（`~/.local/bin` 已在 PATH，不需 alias） |

## 依賴

| 依賴 | 用途 | 備註 |
|------|------|------|
| [Scoop](https://scoop.sh/) | `scoop-interactive-update.ps1` | 僅 Windows |
| [SDKMAN!](https://sdkman.io/) | `sdkupdate` | 僅 Unix；SDKMAN 不支援 Windows 原生 |

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
