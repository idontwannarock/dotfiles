# Tasks — Wave 11: jdtls off Scoop

> 遵守 repo 規矩：先在本機驗證生效，再把變更寫進 source。可行性 spike 已完成（off-scoop 啟動成功）。

## 1. chezmoi-external 條目
- [x] 1.1 `.chezmoiexternal.toml` 在 Windows `{{ if eq .chezmoi.os "windows" }}` 區塊內新增 "Scoop migration — Wave 11" 區段：`$jdtlsVersion = "1.59.0-202605111959"` 與 `[".local/opt/jdtls"]` type=archive、URL 指向 snapshots、**不**加 stripComponents。含維護註解（snapshots prune / version+timestamp 一起 pin）。
- [x] 1.2 本機驗證：`chezmoi apply` 後 `~/.local/opt/jdtls/bin/jdtls` 與 `plugins/org.eclipse.equinox.launcher_*.jar` 存在。

## 2. wrapper 修正（`dot_local/bin/jdtls`，僅 Windows 分支）
- [x] 2.1 `find_real_jdtls` Windows 分支指向 `~/.local/opt/jdtls/bin/jdtls`。
- [x] 2.2 改 exec：Windows 上 `PY=$(uv python find)` 後 `exec "$PY" "$REAL_JDTLS" "$@"`（含 uv 取不到 python 時的錯誤訊息）。
- [x] 2.3 `find_suitable_jdk` Windows 分支移除 scoop JDK 掃描，改信任 `JAVA_HOME` + fallback 掃 `~/.local/opt/jdk-{21,25}`。Linux 分支不動。
- [x] 2.4 本機驗證：`~/.local/bin/jdtls` 啟動 jdtls 成功（JVM boot、無 scoop 參照）。

## 2b. Windows-native jdtls.cmd shim（R1 解決 → 新增）
- [x] 2b.1 新增靜態 source `dot_local/bin/jdtls.cmd`：`uv python find` + `~/.local/opt/jdtls/bin/jdtls`，比照 `java.cmd` 風格。
- [x] 2b.2 本機驗證：PowerShell `Start-Process "jdtls"` 命中 jdtls.cmd、JVM 子行程啟動、`.metadata` 生成、server 存活。

## 3. Wave 11 遷移腳本
- [ ] 3.1 新增 `run_once_after_migrate-scoop-wave11-jdtls.ps1.tmpl`（沿用 wave9/wave10 冪等樣板）：`scoop uninstall jdtls`；未裝 → no-op；scoop 不存在 → 警告 skip；不動 PATH。

## 4. 開放項實測（design R1/R2）
- [x] 4.1 R1 解決：plugin `"command": "jdtls"` 在 native Windows 走 PATHEXT，需 `jdtls.cmd`（見 §2b）。已補 shim 並實測通過。
- [x] 4.2 確認 jdtls 子行程繼承 `JAVA_HOME`（jdtls.py 自 `JAVA_HOME` 取 JDK；實測 jdk-21 通過 ≥21 檢查）。

## 5. 文件
- [x] 5.1 `docs/claude-code.md`：jdtls/JDK 來源那兩行改為 chezmoi-external + `~/.local/opt/jdk-N`。
- [x] 5.2 `README.md`：jdtls 條目未宣稱來源、無 scoop 字樣 → 無需改（保持 surgical）。

## 6. 收尾
- [x] 6.1 本機跑 Wave 11 migrate 腳本：scoop jdtls 卸載 + 殘留 shim（jdtls.exe/jdtls.shim）清除；冪等性已驗證；scoop 全移除後 jdtls 仍正常啟動。
- [x] 6.2 `openspec validate scoop-external-wave11-jdtls --strict` 通過。
- [ ] 6.3 commit 只 stage jdtls 相關檔案（**不**碰 codex-plugins WIP）。
