## Why

Windows 端開發 toolchain（go / python / rust / JDK×6 / maven）目前全部由 Scoop 安裝，而 Scoop 的 `current` junction（`mklink /J`）與 `~/scoop/shims` 在 Win32-OpenSSH session token 下會失效。本機實測：10 個 scoop app 的 `current` 全為 `LinkType=Junction`，go 與 python 另外經由 shims 暴露。這與 Wave 1–9 已逐一解決的 SSH 失效是**同一個 concrete bug**。本變更把這批 Category D toolchain 遷出 Scoop，根除 SSH session 下的 toolchain 失效，並讓 Windows 對齊 Unix 既有的非-scoop 安裝策略（uv / rustup / go-tarball；JDK/maven 因 Windows 無 sdkman 改用 chezmoi-external archive）。

## What Changes

- **go124** → chezmoi-external archive（go.dev `windows-amd64.zip`）落 `~/.local/opt/go`
- **python 311 + 313** → `uv python install 3.11 3.13`：uv 0.8+ 自動把 `python3.11` / `python3.13` 真實 exe 放上 PATH（SSH-safe），**不加 `--default`**（不建立裸 `python` / `python3`，對齊 Unix）。**BREAKING**：scoop 原提供的裸 `python` 不再解析，改打 `python3.13` 或 `uv run`
- **rustup** → 官方 `rustup-init.exe`，全新 `~/.cargo` + `~/.rustup`（**BREAKING**：既有 scoop persist 內 `cargo install` 的 binary 需重裝）
- **temurin 8/11/17/21/25** → chezmoi-external archive 落 `~/.local/opt/jdk-N`
- **maven3** → chezmoi-external archive（Apache `bin.zip`）落 `~/.local/opt/maven`
- **graalvm21-jdk21** + **graalvm-oracle-jdk 25** → 移除（scoop uninstall）：scoop 的 graalvm21 = GraalVM CE 21.0.2，CE 21 線已凍結、不再有安全更新，user 確認不需 graalvm
- **JDK 多版本 UX**：PATH 改放 `%JAVA_HOME%\bin`（**BREAKING**：JAVA_HOME 預設由 temurin 8 → 21）；新增 `java8/11/17/21/25` 的 `.cmd` aliases 與 `use-java <ver>` switcher；per-project 指定 JDK 交給 build-tool toolchain（Maven/Gradle）+ `.git/info/exclude`，dotfiles 不自建機制
- **env 變更**：JAVA_HOME → `~/.local/opt/jdk-21`；CARGO_HOME / RUSTUP_HOME → 預設 `~/.cargo` / `~/.rustup`；User PATH 清除所有 scoop toolchain 條目與 go/python shims
- **新增 Wave 10 migration script**（scoop uninstall + env cleanup，冪等，比照 Wave 8/9 模式）
- **順手修** `run_once_install-01-runtimes.ps1.tmpl` line 40 殘留的 `Install-ScoopPackage "vim"`（Wave 7 遷 vim 時漏清的 orphan）

## Capabilities

### New Capabilities

- `windows-toolchain-provisioning`: Windows 端 go / python / rust / JDK / maven 的非-scoop 安裝（chezmoi-external archive + 原生 installer）、env 與 PATH 接線、以及把既有 scoop 安裝移除的 migration。
- `jdk-version-switching`: 多版本 JDK 的 SSH-safe 使用 UX —— `%JAVA_HOME%\bin` 預設解析、`javaN` `.cmd` aliases、`use-java <ver>` switcher、與 per-project 走 build-tool toolchain 的指引。

### Modified Capabilities

（無 —— `openspec/specs/` 目前為空，無既有 capability 的 requirement 變更。）

## Impact

- **改檔**：`.chezmoiexternal.toml`（+7 archive entries：go + temurin×5 + maven）、`run_once_install-01-runtimes.ps1.tmpl`（Windows 區塊重寫 + vim orphan 修正）、新增 `run_once_after_migrate-scoop-wave10-toolchain.ps1.tmpl`、新增 `dot_local/bin/java{8,11,17,21,25}.cmd` 與 `use-java` switcher fragment、`.chezmoiignore.tmpl`（非 Windows 排除新檔）、`docs/`。
- **影響系統**：Windows User env（JAVA_HOME / CARGO_HOME / RUSTUP_HOME / PATH）；Scoop（uninstall 12 個 package，含兩個 graalvm）。
- **依賴來源**：Adoptium temurin-binaries、Apache Maven、go.dev 發行頁（archive 來源，需 pin 版本）。
- **風險**：本變更等於移除整個 Windows dev toolchain 再重建；依專案規則必須**本機先 `chezmoi apply` + functional 驗證 + SSH session 實測**通過後才 commit / push。
