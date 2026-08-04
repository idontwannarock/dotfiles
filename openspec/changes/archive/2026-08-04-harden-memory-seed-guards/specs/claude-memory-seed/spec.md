## ADDED Requirements

### Requirement: apply 在任何情況下 SHALL exit 0

`claude-memory-seed apply` SHALL 以 exit code 0 結束,無論寫入是否成功。寫入失敗
(目標唯讀、磁碟已滿、權限不足、`jq` 缺席或失敗)SHALL 以 stderr 訊息呈現,SHALL NOT 反映在
退出碼上。

此不變量 SHALL 由 script 自身保證,而非依賴呼叫端包裝:呼叫端有兩處(Claude `SessionStart`
hook 與全域 `post-checkout` dispatcher),其中 `SessionStart` 的 hook command 是裸呼叫,
非零退出會使 session 啟動報錯。

#### Scenario: 寫入目標唯讀時仍 exit 0

- **WHEN** 於一個不可寫的專案目錄執行 apply
- **THEN** exit code 為 0,且失敗原因出現在 stderr

#### Scenario: 護欄拒絕時 exit 0

- **WHEN** 於任一受護欄拒絕的位置執行 apply
- **THEN** exit code 為 0

### Requirement: 寫入 settings 為原子操作,失敗 SHALL NOT 損毀既有檔案

寫入 `settings.local.json` SHALL 先產生同目錄的暫存檔,確認其**存在且非空**後才 rename 覆蓋
目標。`jq` 解析失敗、磁碟寫入失敗等情況 SHALL 使目標檔案保持原內容不變。

SHALL NOT 使用「直接重導向到目標檔」的寫法:重導向會在 `jq` 執行前就截斷目標,而
`printf | jq | tr` 這條 pipeline 的退出碼取自 `tr`,`jq` 的失敗不會反映在其中,因此單看退出碼
無法偵測——必須額外檢查產物非空。

#### Scenario: 既有 settings 格式損毀時不被清空

- **WHEN** 目標 `.claude/settings.local.json` 內容不是合法 JSON,執行 apply
- **THEN** 該檔案內容保持原樣(位元組數不變),且 exit 0

#### Scenario: 正常寫入後不留下暫存檔

- **WHEN** 於一般專案執行 apply 並成功寫入
- **THEN** 目標目錄下不存在暫存檔殘骸

## MODIFIED Requirements

### Requirement: 寫入護欄:三種不得落地的設定位置

`claude-memory-seed apply` SHALL 在解析出 `settings_root` 後、寫入任何檔案**之前**檢查護欄。
當 `settings_root` 符合下列任一條件時 SHALL 安靜 exit 0,SHALL NOT 建立 `.claude/` 目錄、
SHALL NOT 寫入 `settings.local.json`、SHALL NOT 執行遷移:

1. `settings_root` 等於 `$HOME`
2. `settings_root` 等於 `/`
3. `settings_root` 位於 `/tmp/` 之下(含 `/tmp` 本身)

比對 SHALL 為 **resolved-to-resolved**:`settings_root` 是 `pwd -P` 的產物,故 `$HOME` 與
`/tmp` 兩個基準值 SHALL 同樣先解析為 physical path 再比對。單邊解析會使護欄在任一側含
symlink 或尾斜線時永遠不相等而靜默失效;此舉亦使 macOS 的 `/tmp` → `/private/tmp` 自動涵蓋,
無需硬編平台特例。基準值解析失敗時 SHALL 退回原字串,使護欄的失敗方向為「多擋」而非「少擋」。

護欄 SHALL 統一套用,**不區分**該位置是否為 git repo。前綴相同但不在受擋目錄之下的路徑
(如 `/tmpfoo`、`$HOME` 的子目錄)SHALL NOT 被擋。

條件 1 是資料安全需求:該情境下設定路徑會是 `~/.claude/settings.local.json`,即 Claude 的
**user-level** 設定檔;寫入 `autoMemoryDirectory` 會使**所有**未自訂該值的專案共用同一個記憶
目錄。條件 3 阻止拋棄式 checkout 與 scratchpad 在 `~/.claude/memory/` 留下永久孤兒目錄
(`/tmp` 清空後該目錄指向不存在的路徑,永不再被讀取)。

#### Scenario: cwd 為 $HOME 時拒絕寫入

- **WHEN** 於 `$HOME` 執行 `claude-memory-seed apply`
- **THEN** exit 0,且 `~/.claude/settings.local.json` 未被建立或修改

#### Scenario: 經由 symlink 抵達的 $HOME 同樣拒絕

- **WHEN** `$HOME` 指向一個 symlink,於該路徑執行 apply
- **THEN** exit 0,且 symlink 指向的實體目錄下未產生 `.claude/settings.local.json`

#### Scenario: $HOME 本身是 git repo 時同樣拒絕

- **WHEN** `$HOME` 為一個 git repo 的 toplevel(如 yadm/homeshick 佈局),於其中執行 apply
- **THEN** exit 0,且 `~/.claude/settings.local.json` 未被建立或修改

#### Scenario: /tmp 之下拒絕寫入

- **WHEN** 於 `/tmp/<any>` 執行 apply(不論該目錄是否為 git repo)
- **THEN** exit 0,且該目錄下未產生 `.claude/settings.local.json`

#### Scenario: 根目錄拒絕寫入

- **WHEN** 於 `/` 執行 apply
- **THEN** exit code 為 0 且 stderr 無錯誤訊息(不可僅斷言檔案不存在——非特權使用者本就
  無法寫入 `/`,該斷言在護欄被移除時仍會通過)

#### Scenario: 前綴相同但不受擋的路徑仍被種子

- **WHEN** 於 `/tmpfoo`(與 `/tmp` 前綴相同但非其子路徑)執行 apply
- **THEN** 正常寫入 `.claude/settings.local.json`
