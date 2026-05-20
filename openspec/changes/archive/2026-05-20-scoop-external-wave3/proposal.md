## Why

延續 Wave 1（`2026-05-18-scoop-external-wave1`，5 個 CLI）與 Wave 2（`2026-05-20-scoop-external-wave2`，6 個 CLI）的 scoop→chezmoi-external 遷移。Wave 3 收尾 `Install-ScoopPackage` 清單中**剩餘符合單檔模式**的工具：`gopass`。

同時清理兩個**根本不需要 scoop**的 install 呼叫：
- `curl`：Windows 10 build 17063+（2018-04）已將 `curl.exe` 收進 `C:\Windows\System32\`，Git for Windows 也自帶一份。scoop 版只是覆寫，無實質價值。
- `wget`：在 dotfiles 的 `.ps1.tmpl`／PowerShell 流程**完全無人呼叫**。`.sh.tmpl`（Linux/macOS）的 fallback 路徑透過 `apt`/`brew` 安裝，與 Windows 流程無關。

判斷標準延續 `reference_chezmoi_external_cli_tools.md`：單檔 binary、GitHub Release URL 穩定、SSH 場景受益。`gopass` 通過；其餘剩餘 scoop 套件（gpg/ffmpeg/nvm/vim/clink/dark/vimtutor/winget/7z/toolchains/docker/lens）已逐項評估，留作 Wave 4+ 候選或維持 scoop。

## What Changes

**新增 chezmoi-external entry（1 個工具）**：
- `gopass.exe` ← GitHub Release `gopasspw/gopass`，archive `gopass-$ver-windows-amd64.zip` 內 `gopass.exe`

**清理 scoop 安裝呼叫**：
- `run_once_install-cli-tools.ps1.tmpl`：
  - 移除 `Install-ScoopPackage "gopass"`（Wave 3 遷移）
  - 移除 `Install-ScoopPackage "curl"`（Win10+ 內建 + Git for Windows 自帶，無需安裝）
  - 移除 `Install-ScoopPackage "wget"`（Windows 流程未使用）
  - 留下說明註解註明各自的原因

**Active migration on existing machines**：
新增 `run_once_after_migrate-scoop-wave3.ps1.tmpl`：
- `scoop uninstall gopass` 若存在
- `scoop uninstall curl` 若存在
- `scoop uninstall wget` 若存在
- **不需要** PATH 重排序——Wave 1 已搞定

**不動**：
- `gpg` 維持 scoop 安裝（gpg suite 上游為 gnupg.org NSIS `.exe`，非 GitHub，且需要 gpgconf.ctl + gpg2 alias 等 installer side-effects）
- 既有 Wave 1+2 的 external entries、migration 腳本、PATH 設定

**Breaking changes**：
- 既有 Windows 機器執行 `chezmoi apply` 後，`gopass` 會從 scoop 卸載並改由 `~/.local/bin/gopass.exe` 提供
- `curl` 與 `wget` 若曾被 scoop 安裝會被卸載——**包含使用者手動 `scoop install` 的情況**。已驗證 dotfiles 內 Windows `.ps1.tmpl` 無 wget/curl 呼叫，但若使用者個人需求曾手動裝 scoop 版，遷移後該版本會消失，需自行重裝。curl 自動 fallback 到 System32 版（Win10+）或 Git mingw64 版；wget 在 Windows PATH 中直接消失

## Capabilities

### New Capabilities
（無）

### Modified Capabilities
- `tool-dependencies`：新增 1 條 requirement 涵蓋 gopass 在 Windows 上的 chezmoi-external 行為；新增 2 條 requirement 涵蓋 curl/wget 從 scoop install list 移除；新增 1 條涵蓋 Wave 3 一次性遷移腳本（無 PATH 動作）。

## Impact

**Code changes**：
- `.chezmoiexternal.toml`：新增 1 條 gopass entry + version 變數
- `run_once_install-cli-tools.ps1.tmpl`：移除 3 行 `Install-ScoopPackage`（curl/wget/gopass），補上說明註解
- `run_once_after_migrate-scoop-wave3.ps1.tmpl`（新檔）：scoop uninstall 3 個套件

**Existing machine state changes**：
- scoop 卸載 3 個套件（gopass + curl + wget）
- User PATH **不變**（Wave 1 已搞定 ordering）
- corp-ssh-askpass 流程不變：gopass 仍能解出 gpg-agent 加密的密碼，因為 gpg suite 維持 scoop 安裝

**Memory updates（在 archive step 處理）**：
- `reference_chezmoi_external_cli_tools.md` 加入 Wave 3 條目 + "之後 Wave 候選" 子節
- 新增 memory note 記錄 Wave 4 候選清單（gpg/ffmpeg/nvm/vim archive-pattern + 小清理 clink/dark/vimtutor/winget + docker audit）以待後續討論

**Out of scope（Wave 4+ 待討論）**：
- **archive-pattern 候選**：gpg、ffmpeg、nvm-windows、vim-win32-installer（共用「extract 整包到 `~/.local/share/<tool>/` + 加 PATH 條目」新模式）
- **scoop 純清理**（無需 external）：clink、dark、vimtutor、winget、winget-ps（已驗證 dotfiles 未使用）
- **獨立 audit**：Windows host docker / docker-compose 安裝重新評估（user 於 WSL 跑 docker engine）
- **defer**：python / jdk / go / rustup / mvn 多版本管理
- **永不**：lens（GUI app）、7zip（file association）
- **自家 release mirror**（supply-chain pinning）→ 沿用 `project_dotfiles_release_mirror.md`，等所有 Wave 收尾後做
