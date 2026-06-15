## 1. 規劃解析（authoring 前先敲定上游與機制）

- [x] 1.1 archive URL + pin 版本（全部 `stripComponents=1`）：go.dev `go<VER>.windows-amd64.zip`（**local `$goVersion=1.24.13`**，不共用 data var——init-freeze + 避免降版）；Temurin **pinned 到現行已裝版本** 8.0.492/11.0.31/17.0.19/21.0.11/25.0.3（8 命名不同 `jdk8u492-b09`，URL `+`→`%2B`）；Maven `archive.apache.org/.../apache-maven-3.9.16-bin.zip`
- [x] 1.2 graalvm21 distribution = GraalVM **CE 21.0.2**（已凍結）→ user 拍板：**兩個 graalvm 一律移除、不納管**（無 archive entry）
- [x] 1.3 REG_EXPAND_SZ 手法：用 registry API（`[Microsoft.Win32.Registry]::CurrentUser` + `RegistryValueKind.ExpandString` + 廣播 `WM_SETTINGCHANGE`）；**不可**沿用 Wave 9 的 `[Environment]::SetEnvironmentVariable`（會寫成 REG_SZ）
- [x] 1.4 use-java 位置 = `Documents/exact__shared-profile.d/`（PS5+PS7 共用，numeric prefix 如 `22-use-java.ps1`）
- [x] 1.5 uv python bin = `%USERPROFILE%\.local\bin`（已在 PATH）→ **無需 override**
- [x] 1.6 invoke `chezmoi-author` skill（讀 `references/windows.md`）

## 2. chezmoi-external archive entries

- [x] 2.1 go → `~/.local/opt/go`（local `$goVersion=1.24.13`，stripComponents=1）
- [x] 2.2 temurin 8/11/17/21/25 → `~/.local/opt/jdk-{N}`（archive ×5，pinned URL，stripComponents=1）
- [x] 2.3 maven → `~/.local/opt/maven`（`$mavenVersion=3.9.16`，stripComponents=1）

## 3. run_once_install-01-runtimes.ps1.tmpl 改寫（Windows 區塊）

- [x] 3.1–3.5 整個 Windows 區塊改成 **pointer map**（go/python/rust/maven/jdk/vim 全指向 external + wave10 script）；vim orphan 已刪。python/rust **不放此處**（run_once phase 3 早於 external 落地、run_once 不重試）→ 移至 wave10 script

## 4. JDK 多版本 UX 檔案

- [x] 4.1 `dot_local/bin/java{8,11,17,21,25}.cmd`（絕對路徑指 jdk-N/bin/java.exe，LF eol）
- [x] 4.1b **java.cmd + javac.cmd**（SSH-fix）：delegate `%JAVA_HOME%\bin\*.exe`（runtime 展開，繞過 Win32-OpenSSH 不展開 PATH 內 %JAVA_HOME% 的限制）
- [x] 4.2 `use-java <ver>` switcher（只設 User+session JAVA_HOME，java.cmd 自動跟隨）

## 5. Wave 10 migration script

- [x] 5.1–5.3 `run_once_after_migrate-scoop-wave10-toolchain.ps1.tmpl`：guard + scoop uninstall 12 個（含兩 graalvm，冪等）
- [x] 5.4 env：JAVA_HOME→jdk-21、CARGO/RUSTUP_HOME 清 scoop persist、User PATH（REG_EXPAND_SZ）加 go/maven/**cargo** bin + 移除 scoop toolchain。**不放 %JAVA_HOME%\bin**（SSH 不展開 → java.cmd 取代）
- [x] 5.5 scoop uninstall 自動清 go/python shims（無需另寫）
- [x] 5.6 bootstrap：`uv python install`（exact-pin 3.11.15/3.13.13、`UV_PYTHON_INSTALL_DIR`=~/.local/share、`UV_PYTHON_INSTALL_BIN=0`、刪 trampoline+AppData 孤兒）+ `python3.{11,13}.cmd` wrapper + 官方 `rustup-init`
- [x] 5.7 **python SSH-fix**（實機驗證後）：uv trampoline/junction SSH-broken → .cmd wrapper 直指真實 interpreter

## 6. ignore + docs

- [x] 6.1 `.chezmoiignore.tmpl` 非 Windows 排除 java*.cmd + javac.cmd + python3.{11,13}.cmd（switcher 在 Documents/ 已隨 blanket 排除）
- [ ] 6.2 更新 `docs/` 對應文件（可選；OpenSpec spec + memory 已是權威記錄）

## 7. 本機驗證（專案規則：先測再 commit）— 全數通過

- [x] 7.1 `chezmoi apply`（full end-to-end 本機）
- [x] 7.2 functional：go/java×6/javac/cargo/python3.x/mvn 全 OK
- [x] 7.3 **SSH session 實測**（gold standard）：go/java/javac/java8/java25/cargo/rustc/python3.11/python3.13/mvn 全在 localhost SSH 下解析執行、source 全 ~/.local|~/.cargo、零 scoop。**抓到並修掉 java %JAVA_HOME%-PATH + python uv-junction 兩個 SSH-only bug**
- [x] 7.4 冪等性：直接重跑 wave10 script = clean no-op

## 8. 收尾

- [ ] 8.1 commit（feat）+ archive commit；push origin/main
- [ ] 8.2 `openspec archive toolchain-off-scoop`
- [ ] 8.3 更新 memory：`project_scoop_external_wave4_candidates` 的 Category D section + `reference_chezmoi_external_cli_tools` 加 Wave 10 區段
