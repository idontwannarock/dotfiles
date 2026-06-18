# Design — Wave 11: jdtls off Scoop

## Context

延續 Wave 1~10 的「scoop → chezmoi-external」遷移。Wave 10 搬走 JDK/go/python/rust/maven 後，Windows 上僅剩 `jdtls` 仍由 Scoop 管理。本 wave 同時修正 Wave 10 遺留的 wrapper bug（JDK 偵測仍掃已移除的 scoop 路徑）。

本機 spike（已完成）確認可行性：Eclipse jdtls tarball + uv-managed CPython 3.13 + `JAVA_HOME=~/.local/opt/jdk-21` 可完全 off-scoop 啟動（JVM/OSGi 正常 boot，data dir 生出 `.metadata/.log`）。

## Decisions

### D1 — 安裝模式：`type = "archive"` 不加 stripComponents，落點 `~/.local/opt/jdtls`
jdtls tarball 解壓為扁平結構（`bin/ plugins/ config_win/ config_ss_win/ config_* features/`），**無**版本頂層子目錄，故不需 `stripComponents`——對應 Wave 9 nvm 的扁平 archive 模式（而非 Wave 7 vim / Wave 10 jdk 需要 `stripComponents = 1` 剝掉版本目錄那種）。落點選 `~/.local/opt/jdtls`，與 Wave 10 的 app-bundle 慣例（go/jdk/maven/nvm 都在 `~/.local/opt/`）一致；Windows 與 Linux 落點不同（Linux 維持 `~/.local/share/jdtls`）是刻意的——本 wave 只動 Windows，不去統一兩邊路徑以免擴大範圍。

### D2 — URL pinning：snapshots 目錄 + version+timestamp 一起 pin
Eclipse 發佈於 `https://download.eclipse.org/jdtls/snapshots/jdt-language-server-<milestone>-<timestamp>.tar.gz`。`milestones/` 目錄已不含目前安裝的 `1.59.0` build（Eclipse 會 prune）。檔名同時帶 milestone（`1.59.0`）與 build 時間戳（`202605111959`），兩者必須一起 pin（同 Wave 6 ffmpeg 的 `$ffmpegTag` + `$ffmpegAsset`）。**不**用 rolling 的 `jdt-language-server-latest.tar.gz`（破壞 reproducibility）。

**維護註解（寫進 .chezmoiexternal.toml）**：snapshots 目錄的舊 build 可能被 Eclipse 清掉導致 404；升級時更新 `$jdtlsVersion`（milestone+timestamp）並重跑 `chezmoi apply`。

### D3 — Python 依賴：以 `uv python find` 解析，wrapper 用 python 執行 launcher
jdtls 的 `bin/jdtls` 是 `#!/usr/bin/env python3` 腳本（載入 `jdtls.py` 跑 `main()`），**執行期需要 Python 3**。本機 `python`/`python3` 都是 WindowsApps alias stub（不可用）；唯一可用真 Python 是 Wave 10 uv 裝的 CPython（`~/.local/share/uv/python/...`）。

選擇 `uv python find`（spike 驗證會穩定回傳 uv-managed CPython 並忽略 stub）而非：
- 寫死 `~/.local/share/uv/python/cpython-3.*/python.exe` glob — 版本路徑易隨 uv 升級飄移。
- 依賴系統 `python` — 就是壞的。

wrapper Windows 分支因此從「直接 `exec "$REAL_JDTLS"`」改為「`PY=$("$HOME/.local/bin/uv.exe" python find); exec "$PY" "$REAL_JDTLS" "$@"`」。

### D4 — JDK 來源：信任 JAVA_HOME，移除 scoop JDK 掃描
`jdtls.py` 的 `get_java_executable()` 本身會讀 `JAVA_HOME`（若 `$JAVA_HOME/bin/java` 存在就用），且 `22-use-java.ps1` 已把 `JAVA_HOME` 持久設為 `~/.local/opt/jdk-21`。因此 wrapper 的 Windows `find_suitable_jdk` 大幅簡化：不再掃 `~/scoop/apps/temurin*-jdk`（已移除），改為信任既有 `JAVA_HOME`，fallback 掃 `~/.local/opt/jdk-{21,25}`。Linux 分支完全不動。

## Risks / Open Questions

### R1 — plugin 如何在 Windows 呼叫 jdtls（已於實作階段解決 → 新增 jdtls.cmd）
**已解決。** 查證：jdtls-lsp plugin 設定為 `"command": "jdtls"`（bare）。Windows-native 呼叫者（Node / cmd.exe / PowerShell）以 PATHEXT 解析裸命令，只認 `.com/.exe/.bat/.cmd`，**不執行**無副檔名的 bash script `~/.local/bin/jdtls`。實際上 plugin 一直是命中 scoop 的 `jdtls.exe` shim（其 `.shim` 指向 `scoop...python313\python.exe <launcher>`——連 python 都靠 scoop，Wave 10 遷 python 後該 shim 很可能也已壞）。

因此卸載 scoop 後必須在 `~/.local/bin/` 補一個 Windows-native `jdtls.cmd`。`jdtls.cmd` 為靜態 source 檔（比照既有 `java.cmd`），以 `uv python find` 解析 Python 後執行 `~/.local/opt/jdtls/bin/jdtls`（JDK 由 jdtls.py 自 `JAVA_HOME` 取得）。bash wrapper（`~/.local/bin/jdtls`）保留供 Git Bash 使用者，兩條路徑同機制（uv python + jdtls.py + JAVA_HOME）。

實測（PowerShell `Start-Process "jdtls"`，模擬 plugin native 解析）：命中 `jdtls.cmd`、JVM 子行程啟動、workspace `.metadata` 生成、server 持續存活 → 通過。

### R2 — JAVA_HOME 子行程繼承
`JAVA_HOME` 是 User scope 持久變數；正常 Windows session 生出的子行程會繼承。apply 階段順帶確認 Claude Code 生出的 jdtls 行程看得到 `JAVA_HOME`。

## Migration

`run_once_after_migrate-scoop-wave11-jdtls.ps1.tmpl`（沿用 wave9/wave10 命名與冪等樣板）：external 部署後 `scoop uninstall jdtls`；scoop 未裝 jdtls → no-op；scoop 不存在 → 印警告 skip；不動 PATH。
