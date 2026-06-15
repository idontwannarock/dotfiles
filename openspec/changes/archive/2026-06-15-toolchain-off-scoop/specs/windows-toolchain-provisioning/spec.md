## ADDED Requirements

### Requirement: Go 安裝不經由 Scoop

系統 SHALL 在 Windows 透過 `.chezmoiexternal.toml` 的 archive 型別，從 go.dev 下載 `go<ver>.windows-amd64.zip` 並落地 `~/.local/opt/go`，將 `~/.local/opt/go/bin` 加入 PATH。系統 MUST NOT 再經由 Scoop 安裝 go。

#### Scenario: Go 由 external archive 提供
- **WHEN** chezmoi apply 完成
- **THEN** `~/.local/opt/go/bin/go.exe` 存在且為真實檔（非 reparse point），`go version` 回報 ≥ `goMinVersion`

#### Scenario: 不再有 scoop go
- **WHEN** migration 完成後檢查
- **THEN** `scoop list` 不含 `go124`，且 `~/scoop/shims/go.exe` 不存在

### Requirement: Python 由 uv 管理，版本化 .cmd wrapper 上 PATH、SSH-safe、無裸 python

系統 SHALL 用 uv（已遷出 scoop）安裝 exact-pinned python（`UV_PYTHON_INSTALL_DIR` 指 `~/.local/share/uv/python` 以避開不可 SSH-traverse 的路徑），關閉 uv trampolines（`UV_PYTHON_INSTALL_BIN=0`），並以 `dot_local/bin/python3.{11,13}.cmd`（直指真實 interpreter 目錄、繞過 uv junction）暴露 `python3.11` / `python3.13`。系統 MUST NOT 經由 Scoop 安裝 python，MUST NOT 加 `--default`（無裸 python，對齊 Unix），且 `python3.x` MUST 在 SSH session 下可解析執行。

#### Scenario: python3.x 在 SSH session 可用
- **WHEN** 透過 localhost SSH 執行 `python3.11 --version` 與 `python3.13 --version`
- **THEN** 兩者成功回報版本，source 為 `~/.local/bin/python3.*.cmd`（wrapper 直指真實 interpreter，不經 uv junction/trampoline）

#### Scenario: 無裸 python
- **WHEN** 直接執行 `python`（未經 `uv run` / venv）
- **THEN** 不解析到全域 python（僅 `python3.11` / `python3.13` 可用）

#### Scenario: 不再有 scoop python
- **WHEN** migration 完成後檢查
- **THEN** `scoop list` 不含 `python311` 與 `python313`，且 `~/scoop/shims` 不含 `python313.exe` / `python3.exe`

### Requirement: Rust 由官方 rustup 提供

系統 SHALL 以官方 `rustup-init.exe`（`--no-modify-path`、預設 toolchain stable）安裝至預設 `~/.cargo` + `~/.rustup`。系統 MUST NOT 經由 Scoop 安裝 rustup，CARGO_HOME / RUSTUP_HOME MUST NOT 再指向 scoop persist。

#### Scenario: cargo 來自官方 rustup
- **WHEN** chezmoi apply 完成
- **THEN** `~/.cargo/bin/cargo.exe` 存在且為真實檔，`cargo --version` 正常，`rustup` 可自我更新 toolchain

#### Scenario: env 不再指 scoop persist
- **WHEN** migration 完成後檢查 User 環境變數
- **THEN** CARGO_HOME = `~/.cargo`、RUSTUP_HOME = `~/.rustup`，皆不含 `scoop\persist`

### Requirement: JDK 與 Maven 由 external archive 提供

系統 SHALL 以 `.chezmoiexternal.toml` archive 安裝 temurin 8/11/17/21/25 至 `~/.local/opt/jdk-N`、Apache Maven 至 `~/.local/opt/maven`。系統 MUST NOT 再經由 Scoop 安裝這些 JDK 與 maven，且 `graalvm21-jdk21` 與 `graalvm-oracle-jdk` SHALL 一律移除、不再提供（CE 21 已凍結，user 確認不需 graalvm）。

#### Scenario: 五個 temurin JDK 並存於 ~/.local/opt
- **WHEN** chezmoi apply 完成
- **THEN** `~/.local/opt/jdk-{8,11,17,21,25}` 各自含可執行的 `bin/java.exe`（真實檔），且 `~/.local/opt/graalvm21` 不存在

#### Scenario: maven 由 external 提供
- **WHEN** chezmoi apply 完成
- **THEN** `~/.local/opt/maven/bin` 在 PATH，`mvn -version` 正常且其 Java runtime 指向 JAVA_HOME

#### Scenario: 不再有 scoop JDK/maven
- **WHEN** migration 完成後檢查
- **THEN** `scoop list` 不含 `maven3`、`temurin{8,11,17,21,25}-jdk`、`graalvm21-jdk21`、`graalvm-oracle-jdk`

### Requirement: Runtime 安裝腳本不殘留已遷移工具的 Scoop 呼叫

`run_once_install-01-runtimes.ps1.tmpl` MUST NOT 包含任何已遷移工具的 `Install-ScoopPackage` / `scoop install` 呼叫（涵蓋 go / python / rustup / maven / temurin，以及 Wave 7 漏清的 vim orphan），以免 HEAD 自我違反本 spec（沿用 Wave 5 lesson）。

#### Scenario: 腳本無殘留 scoop 安裝行
- **WHEN** grep `run_once_install-01-runtimes.ps1.tmpl`
- **THEN** 無 `Install-ScoopPackage "vim"`，亦無 go124 / python / rustup / maven3 / temurin 的 scoop install 行（僅保留指向 external 的 pointer comment）

### Requirement: 已遷移 toolchain 在 SSH session 下可解析執行

migration 完成後，所有已遷移工具 SHALL 在 Win32-OpenSSH session token 下正常解析與執行，不依賴任何 scoop `current` junction 或 `~/scoop/shims`。

#### Scenario: SSH session 內 toolchain 可用
- **WHEN** 透過 localhost SSH 進入並執行 `go version`、`cargo --version`、`java -version`、`mvn -version`、`uv python list`
- **THEN** 每個命令皆成功解析並回報版本，無 junction/shim 失效錯誤

### Requirement: Migration 冪等

Wave 10 migration script SHALL 冪等：重複執行不報錯、不重複破壞已遷移狀態，並 guard 等待 external binary 先落地後才執行 scoop uninstall 與 env 接線。

#### Scenario: 重跑不爆
- **WHEN** migration script 連續執行兩次
- **THEN** 第二次為 no-op（已 uninstall 的 package 跳過、env 已設則跳過），exit code 0
