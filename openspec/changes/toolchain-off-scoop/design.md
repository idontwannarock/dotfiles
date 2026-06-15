## Context

此 repo 從 Wave 1 起逐步把 Windows CLI 工具遷出 Scoop，根因是 Scoop 的 `current` junction（`mklink /J`）與 `~/scoop/shims` 在 Win32-OpenSSH session token 下會失效（見 `reference_win32_openssh_scoop_ssh_gotchas`）。Wave 9（nvm）進一步釐清：`mklink /D` directory symlink 在 SSH 下**安全**，只有 `/J` junction 與 shims 會炸。

Category D 是最後一批 scoop 依賴：多版本 toolchain（go124、python 311/313、rustup、maven3、temurin JDK ×5）。本機 recon 證實全部中招 —— 10 個 scoop app 的 `current` 全為 `LinkType=Junction`，go 與 python 另經 `~/scoop/shims`（`go.exe`、`python313.exe` 等）。recon 另發現兩個 chezmoi 未管、手動 scoop 安裝的 JDK：`graalvm21-jdk21` 與 `graalvm-oracle-jdk 25`，同樣經 junction 暴露。

非對稱現況：**Unix 端早已非-scoop**（`run_once_install-01-runtimes.sh.tmpl`：JDK/maven 用 sdkman、python 用 uv、rust 用 rustup、go 用官方 tarball），**Windows 端仍全靠 scoop**。

## Goals / Non-Goals

**Goals:**
- 消除 Category D toolchain 對 Scoop 的依賴，使其在 SSH session 下可正常解析與執行（真實檔/原生 installer，零 junction、零 shim）。
- 在可行處讓 Windows 對齊 Unix 既有安裝策略（go / python / rust）。
- 提供多版本 JDK 的 SSH-safe 使用 UX（預設切換 + 各版本手動取用）。

**Non-Goals:**
- 不改動 Unix 端任何安裝邏輯。
- 不自建 per-project JDK 切換機制（jenv 仿作）—— 交給 build-tool 原生 toolchain。
- 不把 python 暴露成 global PATH 上的 `python`（刻意對齊 Unix 的 uv-venv 模型）。
- 不處理非 Category D 的 scoop GUI app（lens、postman 等）。

## Decisions

### D1. Per-tool 混搭，而非統一 archive
go/python/rust 有第一方 cross-platform manager（go.dev zip + GOTOOLCHAIN、`uv python install`、官方 `rustup-init`），對齊 Unix 即可；JDK/maven 因 **Windows 無 sdkman**（bash-only，無 PowerShell port）只能改用 chezmoi-external archive。
- **替代方案（統一 archive）被否決**：archive 化 rustup 會破壞其自我更新 toolchain 的能力（rustup 必須是官方 binary）；archive 化 python 會失去 uv 整合。對 rust/python 反而更糟。

### D2. go → chezmoi-external archive（非 script download）
go.dev 提供乾淨的 `go<ver>.windows-amd64.zip`，用 `.chezmoiexternal.toml` 的 `archive` 型別宣告式落地 `~/.local/opt/go`，與 Wave 6/7/9 一致、版本 pin 在 toml、cache dedup。
- **與 Unix 的差異**：Unix 用 script 下載 tarball 到 `~/.local/go`；Windows 走 external 落 `~/.local/opt/go`。對齊的是**結果**（真實 `go.exe`、GOTOOLCHAIN 管專案版本、無 scoop），非機制。可接受 —— Windows 本來就在多處用 external 取代 Unix 的 script。

### D3. python → uv-managed interpreter + SSH-safe .cmd wrappers（實機 SSH 推翻原「uv-native 免手刻」設計）
uv 已於 Wave 1 遷出 scoop。原設計想靠 uv 0.8+ 的 `python3.x` trampolines（免手刻、對齊 Unix），但**實機 SSH 驗證推翻**：uv 內部用 junction（`cpython-3.13` → `cpython-3.13.13`，`mklink /J`）做版本別名，trampolines / `uv run` / `uv python find` 全部 traverse 這個 junction，SSH restricted token 拒絕（os error 448）；且 uv 預設裝 `%APPDATA%\Roaming\uv\python`，Roaming 在本 corp 環境也是 SSH 不能 traverse 的 reparse point。**只有真實 patch 版目錄能在 SSH 下跑**。最終方案（user 選「保留 uv + .cmd wrapper」）：
- **uv 仍管 interpreter**：exact-pin `3.11.15` / `3.13.13`（使真實目錄名 `cpython-X.Y.Z-windows-x86_64-none` 穩定），`UV_PYTHON_INSTALL_DIR=~/.local/share/uv/python`（traversable）。
- **關掉 uv trampolines**（`UV_PYTHON_INSTALL_BIN=0`）+ 刪殘留 + 清 AppData 孤兒；改用 `dot_local/bin/python3.{11,13}.cmd` **直指真實 interpreter 目錄**（繞過 uv junction，SSH-safe，同 D6 java.cmd 模式）。
- **無裸 `python`**（不加 `--default`，對齊 Unix）。**BREAKING**：裸 `python` 不解析，改打 `python3.13`。
- **教訓**：uv 的「version-manager 免手刻」優勢在 Windows-SSH 下失效（junction 內建於 uv layout）；最終跟 JDK 一樣得手刻 wrapper 指真實路徑。
- **maintenance invariant**：`$pyVersions`（wave10 script）與 `python3.*.cmd` 內 `cpython-X.Y.Z` 目錄名須同 commit bump（同 vim92 模式）。

### D4. rust → 官方 rustup-init，全新 `~/.cargo` + `~/.rustup`
下載官方 `rustup-init.exe`，`-y --default-toolchain stable --no-modify-path`（PATH 由我們的 shell rc 管）。對齊 Unix。
- **BREAKING**：放棄 scoop `persist\rustup` 內既有 `cargo install` 的 binary（需重裝）。選此而非搬遷 persist，因為「全新重抓」最乾淨、可重現，且 user 已確認。

### D5. JDK ×5 + maven → chezmoi-external archive；兩個 graalvm 移除
Adoptium temurin、Apache Maven 皆提供 Windows `.zip`。5 個 temurin 並存（非切換）正好套 Wave 6 `archive × N` 模式，各落 `~/.local/opt/jdk-N`；maven 落 `~/.local/opt/maven`。
- **graalvm21-jdk21 + graalvm-oracle-jdk 25 一律移除（scoop uninstall）**：scoop 的 graalvm21 = GraalVM CE 21.0.2，而 CE 21 線已凍結於 21.0.2（不再有安全更新），user 確認不需 graalvm/native-image → 不納管、不替換成 Oracle。

### D6. JDK 多版本 UX：java.cmd/javac.cmd 包裝 + 各版本 .cmd aliases + use-java switcher
- **預設解析（SSH-safe）**：`dot_local/bin/java.cmd` + `javac.cmd`，內容 `"%JAVA_HOME%\bin\java.exe" %*`。cmd.exe 在 wrapper **執行時**展開 `%JAVA_HOME%`（SSH session 有 JAVA_HOME），故預設 `java`/`javac` 跟隨 use-java 又 SSH-safe。
- **⚠ 為何不把 `%JAVA_HOME%\bin` 直接放 PATH（實機 SSH 驗證推翻原設計）**：Win32-OpenSSH **不展開 PATH 內的 `%JAVA_HOME%` 自訂變數**——SSH session 的 PATH 條目原樣保留字面 `%JAVA_HOME%\bin`，導致 `java` not found（互動 session 會展開，故 simulation 沒抓到，真 SSH 測試抓到）。.cmd wrapper 的 runtime 展開繞過此限制。
- **各版本手動取用**：`dot_local/bin/java{8,11,17,21,25}.cmd`，指向**絕對路徑** `~/.local/opt/jdk-N/bin/java.exe`（真實檔、無 reparse point → SSH-safe，沿用 Wave 7 模式）。
- **切換**：`use-java <ver>` 只設 User + session JAVA_HOME（java.cmd/javac.cmd 自動跟隨，無需重寫 PATH）。
- **替代方案被否決**：(a) `%JAVA_HOME%\bin` 上 PATH → SSH 不展開（實證 broken）；(b) 絕對 jdk-bin 上 PATH + use-java 重寫 PATH → 可行但 switcher 變重，.cmd wrapper 已足；(c) 6 支 raw bin 全上 PATH → 搶第一、污染；(d) PowerShell function alias → SSH `-NoProfile` 下不存在。
- **per-project**：Maven `toolchains.xml` / Gradle `java.installations.paths` + `.git/info/exclude`，dotfiles 不自建（YAGNI）。

### D7. JAVA_HOME 預設 temurin 8 → 21
現況 JAVA_HOME 指 temurin 8（偏舊）。遷移後預設改 temurin 21（最新穩定 LTS，除 25）。**BREAKING**：依賴 JDK 8 的 legacy build 需以 `use-java 8` 或 build-tool toolchain 個別指定。

### D8. 單一 Wave 10 migration script
所有 scoop uninstall + env cleanup（JAVA_HOME / CARGO_HOME / RUSTUP_HOME / PATH / shims 清除）集中於一支 `run_once_after_migrate-scoop-wave10-toolchain.ps1.tmpl`（冪等、guard 等 external 先落地，比照 Wave 8/9）。因為這些工具共用同一組 env-cleanup 關注點，拆多支反而重複。

## Risks / Trade-offs

- **[移除整個 dev toolchain 再重建，中途失敗會無可用 toolchain]** → 依專案規則本機先 `chezmoi apply` + functional + SSH 實測通過才 commit/push；migration script 冪等可重跑；保留「author-only、relocation 留待下次 apply」選項（比照 Wave 9）。
- **[`%JAVA_HOME%\bin` 需寫成 REG_EXPAND_SZ，`[Environment]::SetEnvironmentVariable` 會寫成已展開的 REG_SZ]** → migration script 需以正確 registry value type 寫入（見 Open Questions）。
- **[archive 上游版本/URL 漂移]** → 版本 pin 進 `.chezmoiexternal.toml`；比照既有 external 的 dated-tag / 2-vars pinning 慣例。
- **[兩個 graalvm 移除後若日後需 native-image]** → 屆時再評估納管 Oracle GraalVM 21（維護中）或其他 distro；當前明確不裝。
- **[rust 重裝丟失 cargo bins]** → 已與 user 確認接受；如事後發現缺工具，逐一 `cargo install` 重建。

## Migration Plan

1. 作者化所有 chezmoi 檔案（external entries + 改 runtimes.ps1 + 新 migration script + java*.cmd + use-java + ignore）。
2. 本機 `chezmoi apply`（external 先落地 → migration script 跑 scoop uninstall + env wiring）。**或**比照 Wave 9 採 author-only，relocation 留待下次 apply（user 決定）。
3. Functional 驗證：`go version` / `uv python` / `cargo --version` / `java -version` ×6 + `javaN` aliases + `use-java` 切換 / `mvn -version`。
4. **SSH session 實測**（gold standard，呼應 driver）：localhost SSH 進去逐一 invoke，確認解析與執行。
5. 冪等性：再跑一次 run_once 不爆。
6. 通過後 commit / push；`openspec archive`。
- **Rollback**：未 push 前 `git restore` + `scoop install` 還原；scoop manifest 仍在上游可重裝。

## 規劃研究結論（2026-06-12，task 1）

- **Archive（全部 `stripComponents=1`）**：
  - Go：`https://go.dev/dl/go<VER>.windows-amd64.zip`（top-level `go/`）；**本地 pin `$goVersion=1.24.13`**（不共用 Unix `goLinuxTarballVersion` data var——config data 在 init 凍結、且共用會從現行 1.24.13 降版；兩平台 Go pin 容許 drift，皆 ≥ goMinVersion）。
  - Temurin（**pinned 具體版本**，對齊 Unix sdkman pinning + supply-chain 慣例；pin 到現行已裝版本 8.0.492/11.0.31/17.0.19/21.0.11/25.0.3）。**8 命名不同**：tag `jdk8u492-b09`、asset `OpenJDK8U-jdk_x64_windows_hotspot_8u492b09.zip`；11+ 為 `jdk-<V>+<B>`（URL 中 `+`→`%2B`，asset 用 `_`）。
  - GraalVM：**不納管**（CE 21 凍結，user 選擇移除兩個 graalvm）→ 無 archive entry。
  - Maven：`https://archive.apache.org/dist/maven/maven-3/3.9.16/binaries/apache-maven-3.9.16-bin.zip`（top-level `apache-maven-3.9.16/`）。
- **uv python bin**：Windows 預設落 `%USERPROFILE%\.local\bin`（已在 PATH）→ 無需 override（path override 變數是 `UV_PYTHON_BIN_DIR`，非 boolean 的 `UV_PYTHON_INSTALL_BIN`）。
- **REG_EXPAND_SZ**：`[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment',$true)` + `GetValue(...,DoNotExpandEnvironmentNames)` 讀、`SetValue('Path',$v,[…RegistryValueKind]::ExpandString)` 寫、廣播 `WM_SETTINGCHANGE`。**注意**：Wave 9 既有 PATH 寫法（`[Environment]::SetEnvironmentVariable`）會寫成 REG_SZ → JAVA_HOME 條目必須改走此 registry API。
- **use-java 位置**：`Documents/exact__shared-profile.d/`（PS5+PS7 共用，numeric prefix）。
- **aliases**：只做 `javaN`（最小集，不做 `javacN`）。

## Open Questions

（全部已解析。OQ1 GraalVM distro 已拍板：**兩個 graalvm 一律移除、不納管**，不替換成 Oracle。）
