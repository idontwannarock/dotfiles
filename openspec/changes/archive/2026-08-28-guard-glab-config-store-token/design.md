## Context

wrapper 已經把「正門」做對了:權杖於呼叫當下自 vault 取,只以 env 傳給該次呼叫。
本次要處理的是**旁路** —— `glab auth login` 與不帶 `--global` 的
`glab config set token …`,兩者都直接寫明文 YAML,wrapper 沒有機會介入。

## Goals / Non-Goals

**Goals**
- config store 一旦帶有權杖,下一次 `glab` 呼叫就發出聲音,而不是等下一次人工翻檔。
- 訊息要能單獨行動:給清除指令,並指出必須輪替。

**Non-Goals**
- 不阻止 `glab auth login` 執行本身(它就是走 wrapper 的,但擋在事前等於猜使用者
  的意圖;擋在事後才有確定的證據 —— 檔案裡真的有東西)。
- 不做 YAML 剖析。

## Decisions

### 拒絕執行,而不是印警告後照跑

<!-- evergreen-candidate -->
一道每次都放行的警告,使用者會學會讀過去 —— 這在本 repo 已有前例
(`chezmoi` guard 之所以有效,是因為它只在失敗路徑上出現)。而這裡的補救成本極低
(一行指令),所以擋下的代價小於漏掉的代價。以 1 結束,與既有兩道守衛一致。

### 只擋不改:守衛不自動清除權杖

自動清除會讓檔案恢復乾淨,於是「這顆權杖曾經明文落地、必須輪替」這個唯一重要的
後果消失在無聲之中。守衛存在的目的是讓人知道要輪替,不是讓檔案看起來乾淨。

### 檢查兩個 store,不是一個

`glab config set token x` 不帶 `--global` 時寫的是 `$(git rev-parse --git-dir)/glab-cli/config.yml`。
只查 global 的守衛,其宣稱(「config store 沒有權杖」)在 repo-local 那半邊是假的 ——
一個只在一半情況下為真的綠燈,比沒有綠燈更糟。代價是每次呼叫多一個
`git rev-parse` 子行程;`glab` 是網路命令,不在熱路徑上。

### 路徑解析:`GLAB_CONFIG_DIR`,不是 `XDG_CONFIG_HOME`

實測(glab 1.112.0):設 `GLAB_CONFIG_DIR` 到暫存目錄,glab 在該目錄下建
`config.yml` 與 `aliases.yml`;設 `XDG_CONFIG_HOME` 則**無效**,glab 仍寫
`~/.config/glab-cli`。因此 global 路徑取
`${GLAB_CONFIG_DIR:-$HOME/.config/glab-cli}/config.yml`,不看 `XDG_CONFIG_HOME`。

### 偵測用 regex,並明確界定誤判邊界

判為「有權杖」的條件:某行去除前導空白後以 `token:` 或 `job_token:` 開頭,且冒號
後存在非空白字元。這條線之所以站得住:

- glab 寫出的 config.yml 帶有大量自帶註解,其中包含 `# Your GitLab access token…`
  與 `#   value: Bearer token123`。兩者去除前導空白後都以 `#` 開頭,不匹配。
- 清空後 glab 直接把該 key **整行移除**(本機實測),空值形式因此少見;但
  `token:`(冒號後只有空白或換行)仍必須放行,否則 gitlab.com 那個空欄位會讓守衛
  永遠亮紅燈。
- `job_token:` 必須單獨列出:`^token:` 匹配不到它,而 CI job token 同樣是憑證。

不引入 YAML parser —— 這條路要求 shell 啟動路徑上多一個依賴,而收益只是覆蓋一種
本機不會出現的縮排形式。

### 守衛的位置:host 檢查之後,vault 讀取之前

放在 vault 讀取之前,是為了讓一個注定被拒絕的呼叫不觸發 gpg pinentry。放在 host
檢查之後,是因為既有測試已釘住「host 未設定時看到 host 的訊息」,而兩者同時錯時
host 是更根本的成因。

## Risks / Trade-offs

- **誤判會讓 `glab` 完全不能用。** 緩解:訊息直接給出清除指令與檔案路徑;真要繞過
  仍可用文件已載明的 `command glab …`。
- **`grep` 不在 PATH 上時守衛 fail-open。** bash 版以 `grep -q … || continue` 判斷,
  而 `command not found` 的 127 與「沒有匹配」的 1 都落進 `continue`。實測確認
  (刻意移除 PATH 上的 grep,守衛靜默放行)。接受而不修:沒有 `grep` 的 shell 連
  `command -v pass` 之外的整個 wrapper 都不成立,而區分兩種退出碼要為一個不存在的
  情境多寫一層。PowerShell 版用 `Select-String`,沒有這個形態。

- **兩平台訊息逐字一致是人工維持的。** 既有 spec 已有此要求,PowerShell 端有
  Pester 測試釘住;bash 端沒有對應測試框架,靠 code review 比對 —— 這是既有現狀,
  本次不擴大。
