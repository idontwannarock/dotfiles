# jdk-version-switching Specification

## Purpose
TBD - created by archiving change toolchain-off-scoop. Update Purpose after archive.
## Requirements
### Requirement: 預設 java/javac 跟隨 JAVA_HOME（SSH-safe wrapper）

系統 SHALL 提供 `dot_local/bin/java.cmd` 與 `javac.cmd`，delegate 至 `"%JAVA_HOME%\bin\java.exe"`（cmd.exe 於 wrapper 執行時展開 `%JAVA_HOME%`）。預設 JAVA_HOME SHALL 指向 `~/.local/opt/jdk-21`（temurin 21）。系統 MUST NOT 把 `%JAVA_HOME%\bin` 或任何 JDK raw bin 放上 PATH——Win32-OpenSSH 不展開 PATH 內的 `%JAVA_HOME%`，會使 SSH 下 `java` not found。

#### Scenario: SSH session 下 java/javac 解析到 JAVA_HOME 版本
- **WHEN** 透過 localhost SSH 執行 `java -version` 與 `javac -version`（JAVA_HOME=jdk-21）
- **THEN** 兩者回報 temurin 21，source 為 `~/.local/bin/java.cmd` / `javac.cmd`（非 scoop、非 PATH 上的 jdk bin）

#### Scenario: 改 JAVA_HOME 後 java 自動跟隨
- **WHEN** 將 JAVA_HOME 改指 `~/.local/opt/jdk-17`
- **THEN** `java -version` 回報 17（wrapper runtime 展開新的 %JAVA_HOME%），無需改 PATH

### Requirement: 各版本 .cmd alias 供手動取用

系統 SHALL 提供 `dot_local/bin/java{8,11,17,21,25}.cmd` static wrapper，各自指向對應 `~/.local/opt/jdk-N/bin/java.exe` 的**絕對路徑**。這些 wrapper MUST 為真實檔（無 reparse point），以在 SSH session 下安全運作。

#### Scenario: alias 解析到指定版本
- **WHEN** 執行 `java17 -version`
- **THEN** 回報 temurin 17，與當前 JAVA_HOME 無關

#### Scenario: alias 在 SSH session 下可用
- **WHEN** 透過 localhost SSH 執行 `java21 -version`
- **THEN** 成功回報 temurin 21（wrapper 為真實 .cmd，不受 junction/shim 失效影響）

### Requirement: use-java switcher 切換預設 JDK

系統 SHALL 提供 `use-java <ver>` switcher，將 User-level JAVA_HOME 設為對應 `~/.local/opt/jdk-<ver>`（持久，供新 session 與程式），並同步更新當前 session 的 `$env:JAVA_HOME`。java.cmd/javac.cmd 隨即跟隨，無需重寫 PATH。

#### Scenario: 當前 session 即時切換
- **WHEN** 在已開啟的 session 執行 `use-java 8`
- **THEN** 同一 session 內 `java -version` 立即回報 temurin 8，且 User JAVA_HOME 已持久更新為 jdk-8

#### Scenario: 無效版本被拒
- **WHEN** 執行 `use-java 14`（未安裝）
- **THEN** switcher 報錯並不更動 JAVA_HOME

