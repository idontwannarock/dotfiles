## ADDED Requirements

### Requirement: JDK external 寫出的唯讀檔案 SHALL 於 apply 前解除唯讀

系統 SHALL 在 target state 套用之前,清除 `~/.local/opt/jdk-*` 底下所有檔案的 `ReadOnly` 屬性。

Windows 上 `chezmoi apply` 解壓 JDK external archive 時,會把 zip entry 的唯讀權限位
映射為 DOS `ReadOnly` 檔案屬性;下次升版覆寫同一路徑會被 Windows 以 `Access is denied`
拒絕,使覆寫無法進行。

#### Scenario: JDK 版本 pin 變動後 apply 不被唯讀檔擋住

- **WHEN** `.chezmoiexternal.toml` 的任一 JDK 版本 pin 與機器上已安裝版本不同,且舊版留下
  帶 `ReadOnly` 屬性的檔案(如 `bin/server/classes.jsa`)
- **THEN** `chezmoi apply` 在 Windows 上完成該 JDK 的升級,不出現 `Access is denied`

#### Scenario: 清除範圍涵蓋全部五個 JDK

- **WHEN** 清除腳本執行
- **THEN** `~/.local/opt/jdk-8`、`jdk-11`、`jdk-17`、`jdk-21`、`jdk-25` 底下所有帶
  `ReadOnly` 屬性的檔案都被解除,而非只有當次要升級的那一個 JDK

#### Scenario: 無版本異動時不付掃描成本

- **WHEN** 連續兩次 `chezmoi apply` 之間五個 JDK 的版本 pin 都沒有變動
- **THEN** 第二次 apply 不執行該清除腳本

#### Scenario: 非 Windows 平台不部署此腳本

- **WHEN** 在 Linux 或 macOS 上執行 `chezmoi apply`
- **THEN** 該腳本不存在於 target state,apply 行為不變

### Requirement: apply 中止 SHALL 對使用者明示後續 target 未部署

系統 SHALL 在 `chezmoi apply` 或 `chezmoi update` 非零退出時,主動告知使用者字典序在其後的 target 未部署,並報出待處理項目筆數。

chezmoi 依 target path 字典序處理且沒有 skip-on-error,任一 target 失敗會使字典序在其後的
所有 target 靜默落空;chezmoi 自身的輸出不會揭露這件事。

#### Scenario: apply 失敗時印出警告與待處理筆數

- **WHEN** 使用者在互動 shell 執行 `chezmoi apply` 或 `chezmoi update` 且該命令非零退出
- **THEN** 終端印出警告,說明字典序在失敗項之後的 target 未部署,並附上目前待處理的項目筆數

#### Scenario: 成功路徑不受影響

- **WHEN** `chezmoi apply` 或 `chezmoi update` 以 0 退出
- **THEN** 不印出任何額外輸出,且不執行 `chezmoi status`

#### Scenario: 其他 chezmoi 子命令不受影響

- **WHEN** 使用者執行 `chezmoi status`、`chezmoi diff` 等其他子命令,無論退出碼為何
- **THEN** 行為與未包裝時完全相同

#### Scenario: 三個 shell 皆具備此行為

- **WHEN** 使用者在 pwsh、bash 或 zsh 的互動 shell 中觸發 apply 失敗
- **THEN** 三者都印出同一則警告
