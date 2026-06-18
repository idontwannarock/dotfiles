## ADDED Requirements

### Requirement: jdtls 套件本體在 Windows 上由 chezmoi-external 整包安裝
Windows 上 jdtls（Eclipse JDT Language Server：`bin/` launcher + `plugins/` OSGi jars + `config_win/` / `config_ss_win/` / `features/` 等）SHALL 由 `.chezmoiexternal.toml` 從 Eclipse 下載 `jdt-language-server-<version>.tar.gz`，以 `type = "archive"` 整包解壓至 `~/.local/opt/jdtls/`，產生扁平結構（`bin/jdtls`、`bin/jdtls.py`、`plugins/org.eclipse.equinox.launcher_*.jar` 等）。tarball 無版本頂層子目錄，故 **SHALL NOT** 使用 `stripComponents`。

版本以 chezmoi template 變數 `$jdtlsVersion` pinning（如 `1.59.0-202605111959`，milestone + build 時間戳），URL 形式：`https://download.eclipse.org/jdtls/snapshots/jdt-language-server-{{ $jdtlsVersion }}.tar.gz`。

#### Scenario: Windows 上下載並整包解壓 jdtls
- **WHEN** chezmoi apply 在 Windows 執行
- **THEN** `.chezmoiexternal.toml` 自 `https://download.eclipse.org/jdtls/snapshots/jdt-language-server-<version>.tar.gz` 下載並解壓至 `~/.local/opt/jdtls/`，最終 `~/.local/opt/jdtls/bin/jdtls` 與 `~/.local/opt/jdtls/plugins/org.eclipse.equinox.launcher_*.jar` 存在

#### Scenario: 版本 pinning 確保跨機器 reproducible
- **WHEN** 同一 commit 在不同機器、不同時間執行 chezmoi apply
- **THEN** 解壓得到的 jdtls 版本一致——pinning 採 `$jdtlsVersion`（milestone+時間戳），**不**使用 rolling `jdt-language-server-latest.tar.gz`

### Requirement: jdtls wrapper Windows 分支指向 off-scoop 安裝並以 uv-managed Python 執行
`dot_local/bin/jdtls` wrapper 的 Windows（`MINGW*`/`MSYS*`）分支 SHALL NOT 參照任何 `~/scoop/apps/...` 路徑。`find_real_jdtls` SHALL 指向 `~/.local/opt/jdtls/bin/jdtls`。因該 launcher 為 `#!/usr/bin/env python3` 腳本，wrapper SHALL 以一個可用的 Python 3 直譯器執行它——透過 `uv python find` 解析（系統 `python`/`python3` 為 WindowsApps alias stub，不可用），即 `exec "$PY" "$REAL_JDTLS" "$@"`。

#### Scenario: wrapper 以 off-scoop jdtls + uv python 啟動
- **WHEN** Windows 上呼叫 `~/.local/bin/jdtls`
- **THEN** wrapper 解析 `~/.local/opt/jdtls/bin/jdtls`，以 `uv python find` 取得的 CPython 執行該 launcher，jdtls JVM 正常啟動（不參照任何 scoop 路徑）

#### Scenario: 系統 python 為不可用 stub 時仍能取得真 Python
- **WHEN** 系統 `python` 解析到 WindowsApps alias stub
- **THEN** wrapper 使用 `uv python find` 回傳的 uv-managed CPython，而非 stub

### Requirement: Windows-native jdtls.cmd shim 供 PATHEXT 解析的呼叫者
`~/.local/bin/` SHALL 包含一個 `jdtls.cmd`，作為無副檔名 bash wrapper 的 Windows-native 對應物，供以 PATHEXT 解析命令的呼叫者（Node / cmd.exe / PowerShell，含 Claude Code jdtls-lsp plugin 的 `"command": "jdtls"`）使用——這類呼叫者無法執行無副檔名的 bash script，且 scoop 的 `jdtls.exe` shim 已於 Wave 11 移除。`jdtls.cmd` SHALL 以 `uv python find` 解析出的 Python 執行 `~/.local/opt/jdtls/bin/jdtls`，JDK 由 `jdtls.py` 自 `JAVA_HOME` 取得。`jdtls.cmd` 為靜態 source 檔（`dot_local/bin/jdtls.cmd`），與既有 `java.cmd` 等 `.cmd` wrapper 同類。

#### Scenario: plugin 的 bare "jdtls" 命令解析到 jdtls.cmd 並啟動 server
- **WHEN** Node / PowerShell / cmd.exe 以 PATHEXT 解析裸命令 `jdtls`（`~/.local/bin` 在 PATH 早於 `~/scoop/shims`）
- **THEN** 命中 `~/.local/bin/jdtls.cmd`，以 uv-managed Python 啟動 `~/.local/opt/jdtls/bin/jdtls`，jdtls language server 持續存活（JVM 子行程運作、workspace `.metadata` 生成）

#### Scenario: scoop jdtls.exe 移除後仍可由 native 呼叫者啟動
- **WHEN** scoop `jdtls` 已卸載（`~/scoop/shims/jdtls.exe` 不存在）
- **THEN** native 呼叫者改命中 `~/.local/bin/jdtls.cmd`，jdtls 正常啟動，不依賴任何 scoop 路徑

### Requirement: jdtls wrapper Windows 分支的 JDK 來源改為 JAVA_HOME / ~/.local/opt
`dot_local/bin/jdtls` wrapper 的 Windows 分支 SHALL NOT 掃描 Wave 10 已移除的 `~/scoop/apps/temurin*-jdk` / `graalvm*` 路徑。JDK 來源 SHALL 為既有的 `JAVA_HOME`（`22-use-java.ps1` 持久設為 `~/.local/opt/jdk-21`，且 `jdtls.py` 的 `get_java_executable()` 本身會讀 `JAVA_HOME`），fallback 為掃描 `~/.local/opt/jdk-{21,25}` 等實體目錄。

#### Scenario: 沿用既有 JAVA_HOME
- **WHEN** Windows 上 `JAVA_HOME` 指向 `~/.local/opt/jdk-21` 且其 `bin/java.exe` 存在
- **THEN** jdtls 以該 JDK 啟動（`jdtls.py` 通過 `--validate-java-version` 的 ≥21 檢查），wrapper 不因 scoop JDK 不存在而報 "No JDK >= 21 found"

#### Scenario: 不再參照已移除的 scoop JDK 路徑
- **WHEN** `~/scoop/apps` 下無任何 temurin/graalvm JDK（Wave 10 後的狀態）
- **THEN** wrapper 仍能找到 JDK 並啟動 jdtls（來源為 `JAVA_HOME` 或 `~/.local/opt/jdk-N`）

### Requirement: Windows 上 jdtls 不再經由 Scoop
任何 install 腳本 SHALL NOT 主動 `scoop install jdtls`。Windows 上 jdtls 由 `.chezmoiexternal.toml` 提供。文件（`docs/claude-code.md`、`README.md`）SHALL 標明 jdtls 由 chezmoi-external 提供、JDK 來自 `~/.local/opt/jdk-N`。

#### Scenario: 乾淨 Windows 首次 apply 不裝 scoop jdtls
- **WHEN** 在乾淨 Windows 上首次 `chezmoi apply`
- **THEN** 無腳本執行 `scoop install jdtls`；jdtls 由 `.chezmoiexternal.toml` 提供

### Requirement: Wave 11 一次性遷移腳本
`run_once_after_migrate-scoop-wave11-jdtls.ps1.tmpl` SHALL 在 Windows 上執行一次性遷移：卸載 scoop 套件 `jdtls`，並清除卸載後殘留於 `~/scoop/shims` 的 jdtls shim（`jdtls`、`jdtls.exe`、`jdtls.cmd`、`jdtls.shim`、`jdtls.ps1`），以免過期 shim 與 `~/.local/bin/jdtls.cmd` 競爭。腳本 SHALL 為冪等：scoop 未安裝 jdtls 時跳過 uninstall 但仍清 shim；scoop 整個未安裝時印警告並 skip。腳本 SHALL NOT 動 User PATH，且 SHALL NOT 觸及 `~/.local/bin`。

#### Scenario: 已安裝 scoop jdtls 被卸載並清除殘留 shim
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list jdtls` 回報已安裝
- **THEN** 腳本執行 `scoop uninstall jdtls`，並移除 `~/scoop/shims` 下殘留的 jdtls shim；`~/.local/bin/jdtls.cmd` 不受影響

#### Scenario: scoop jdtls 未安裝時仍清殘留 shim（冪等）
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list jdtls` 回報未安裝
- **THEN** 腳本不執行 `scoop uninstall`，但仍移除任何殘留的 `~/scoop/shims/jdtls*` shim，再結束

#### Scenario: scoop 未安裝時整支 skip
- **WHEN** chezmoi apply 在 Windows 執行，且 `Get-Command scoop` 回 not found
- **THEN** 腳本印警告訊息並 return，不嘗試任何 scoop 命令
