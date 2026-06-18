## Why

承 Wave 1~10 的 scoop → chezmoi-external 系列，Windows 上仍由 Scoop 管理的開發工具只剩 `jdtls`（Eclipse JDT Language Server，Claude Code 的 Java LSP，現版 `1.59.0-202605111959`）。它跟其他工具一樣吃 Scoop 的 `current` junction + shim 在 Win32-OpenSSH SSH session 下失效的風險。

更急的是一個**已存在的 bug**：Wave 10 把 JDK 搬到 `~/.local/opt/jdk-N` 並移除了 scoop JDK，但 `dot_local/bin/jdtls` wrapper 的 Windows 分支仍在掃 `~/scoop/apps/temurin*-jdk/current`——那些目錄已不存在。所以 Windows 上這個 wrapper 的 JDK 偵測**現在就是壞的**。把 jdtls 遷離 Scoop 正好是修正 wrapper 的時機，兩件事在同一處改一次完成。

## What Changes

**chezmoi-external 新條目（Windows-only，置於既有 `{{ if eq .chezmoi.os "windows" }}` 區塊內）**：
- `~/.local/opt/jdtls/`：從 Eclipse 下載 `jdt-language-server-<version>.tar.gz`，以 `type = "archive"` 整包解壓（**不**加 `stripComponents`——tarball 為扁平結構：`bin/`、`plugins/`、`config_win/`、`config_ss_win/`、`config_*`、`features/`，無版本頂層子目錄，同 Wave 9 nvm 模式）。版本以 chezmoi template 變數 pinning，URL：`https://download.eclipse.org/jdtls/snapshots/jdt-language-server-{{ $jdtlsVersion }}.tar.gz`（`$jdtlsVersion` = `1.59.0-202605111959`，milestone + build 時間戳一起 pin，同 Wave 6 ffmpeg；附維護註解：snapshots 目錄舊 build 可能被 Eclipse 清掉，升級時需同時更新 version+timestamp）。

**修正 `dot_local/bin/jdtls` wrapper 的 Windows 分支**：
- `find_real_jdtls()`：Windows 改指向 `~/.local/opt/jdtls/bin/jdtls`（取代 scoop 路徑）。
- 執行方式：`bin/jdtls` 是 `#!/usr/bin/env python3` 腳本，不能直接 `exec`。Windows 上以 `uv python find` 解析出可用的 Python 後 `exec "$PY" "$REAL_JDTLS" "$@"`（系統 `python`/`python3` 是 WindowsApps alias stub，不可用；`uv python find` 會穩定回傳 Wave 10 uv-managed CPython 並自動忽略 stub）。
- `find_suitable_jdk()`：Windows 分支不再掃已不存在的 scoop JDK 路徑。改為信任既有 `JAVA_HOME`（`22-use-java.ps1` 已持久設為 `~/.local/opt/jdk-21`，且 `jdtls.py` 的 `get_java_executable()` 本身就會讀 `JAVA_HOME`），fallback 掃 `~/.local/opt/jdk-{21,25,...}`。

**Wave 11 一次性遷移腳本**：
- 新增 `run_once_after_migrate-scoop-wave11-jdtls.ps1.tmpl`（沿用 wave9/wave10 命名）：在 external 部署後執行 `scoop uninstall jdtls`。冪等：scoop 未安裝 jdtls 時 no-op；scoop 整個未安裝時 skip。不動 User PATH（Wave 1 已處理 ordering）。

**文件更新**：
- `docs/claude-code.md`（jdtls/JDK 來源說明那兩行）、`README.md`（jdtls 條目）改為標明 jdtls 由 chezmoi-external 提供、JDK 來自 `~/.local/opt/jdk-N`。

**不動**：
- macOS / Linux 的 jdtls（早已不靠 scoop，wrapper Linux 分支維持 `~/.local/share/jdtls` 不變）。
- 既有 Wave 1~10 entries、migration 腳本、PATH 設定。
- working tree 內不相關的 codex-plugins WIP（不在本 change 範圍，commit 時不 stage）。

**Breaking changes**：
- 既有 Windows 機器 `chezmoi apply` 後，scoop `jdtls` 被卸載，改由 `~/.local/opt/jdtls` + 修正後的 wrapper 接手。

## Capabilities

### New Capabilities
（無）

### Modified Capabilities
- `tool-dependencies`：新增 requirement——jdtls 套件 archive 整包安裝（Windows）；jdtls wrapper Windows 分支改指向 off-scoop 位置、以 uv-managed Python 執行、JDK 來源改為 `JAVA_HOME` / `~/.local/opt/jdk-N`；Windows 上 jdtls 不再經由 Scoop；Wave 11 一次性遷移腳本。

## Impact

**Code changes**：
- `.chezmoiexternal.toml`：新增 Wave 11 區塊，含 1 條 `archive` external entry 與 pinned `$jdtlsVersion` 變數。
- `dot_local/bin/jdtls`：改寫 Windows 分支的 `find_real_jdtls` / `find_suitable_jdk` / exec 路徑（Linux 分支不動）。
- `run_once_after_migrate-scoop-wave11-jdtls.ps1.tmpl`（新檔）：Windows-only，冪等 `scoop uninstall jdtls`。
- `docs/claude-code.md`、`README.md`：更新 jdtls/JDK 來源描述。

**Existing machine state changes**：
- Scoop 卸載 1 個套件（`jdtls`）。
- `~/.local/opt/jdtls/` 出現（~50 MB tarball 解壓）。
- User PATH **不變**。

**需在 apply 階段實測確認的開放項**：
- Claude Code 的 jdtls-lsp plugin 在 Windows 上實際如何呼叫此 bash wrapper（node spawn 對無副檔名 bash script 的處理）；確認遷移後 plugin 仍能啟動 jdtls，必要時補 `.cmd` shim。
- 確認 `JAVA_HOME`（User 持久變數）被 Claude Code 生出的 jdtls 子行程繼承。

**Out of scope**：
- macOS/Linux jdtls 管理（原生套件 / 既有同步腳本）。
- 多版本 JDK 切換機制本身（Wave 10 的 `jdk-version-switching` 已涵蓋）。
