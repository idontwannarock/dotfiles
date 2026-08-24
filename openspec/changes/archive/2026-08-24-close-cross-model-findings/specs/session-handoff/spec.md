## ADDED Requirements

### Requirement: 守衛的診斷 SHALL 指認實際的錯誤形狀

`tests/path-format-flag-order.test.sh` 存在的理由是分辨兩種靜默失敗——旗標置後與旗標省略。因此它的失敗訊息 SHALL 指認實際踩到的那一種,SHALL NOT 將其一報成其二。

其驗證 SHALL 斷言**訊息內容**,SHALL NOT 只斷言測試變紅。只斷言顏色的驗證對「兩種錯誤都紅但診斷互換」完全失明,而那正是 2026-08-24 該缺陷連續存活三輪 review 的原因。

#### Scenario: 置後與省略各自的診斷

- **WHEN** 掃到旗標置於 `--git-common-dir` 之後的呼叫點
- **THEN** 訊息 SHALL 指出旗標置後,SHALL NOT 指出旗標缺失
- **AND** 掃到完全沒有 `--path-format` 的呼叫點時 SHALL 指出旗標缺失

#### Scenario: 判定值不得被中介指令覆寫

- **WHEN** 判定函式以 exit status 回傳結果
- **THEN** 該值 SHALL 於函式返回後立即存入變數,SHALL NOT 在經過 `case`、`if` 等會重設 `$?` 的指令之後才讀取

### Requirement: 反斜線接續的呼叫在母體之內

以反斜線接續跨越多個實體行的單一 `rev-parse` 呼叫 SHALL 進入守衛的母體。此類接續是**一個語法上的呼叫**,不屬於「不做跨行變數流分析」所排除的範圍。

掃描 SHALL 先將反斜線接續行併為邏輯行後再判定,且回報的行號 SHALL 為該邏輯行的**第一個實體行** —— 使用者要編輯的是呼叫的起點,不是恰好含 `--git-common-dir` 的那一行。

#### Scenario: 跨行的省略

- **WHEN** 呼叫寫成 `git rev-parse \` 換行 `  --git-common-dir` 且無 `--path-format=absolute`
- **THEN** 測試 SHALL 失敗,並 SHALL 指向該呼叫的起始行

### Requirement: 掃到的檔案數 SHALL 被斷言

守衛 SHALL 對掃到的檔案數設下限並斷言之,SHALL NOT 僅於成功訊息中列印。

理由:per-root 的呼叫點下限會隨樹成長而相對寬鬆,其緩解正是同時斷言檔案數。一個寫在 design 裡卻未實作的緩解,比沒有緩解更糟——它讓讀 design 的人以為那個方向已經被守住。

#### Scenario: 檔案數低於下限

- **WHEN** 掃到的檔案數低於下限
- **THEN** 測試 SHALL 失敗

#### Scenario: 計數用的走訪同樣不得吞錯誤

- **WHEN** 計算檔案數的 `find` 遇到讀取錯誤
- **THEN** SHALL 與主掃描適用同一規則:stderr 有內容即失敗,SHALL NOT 以 `2>/dev/null` 丟棄
