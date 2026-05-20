## Context

延伸 Wave 1（`2026-05-18-scoop-external-wave1`）+ Wave 2（`2026-05-20-scoop-external-wave2`）的 chezmoi-external 模式。Wave 3 收尾**剩餘符合單檔 GitHub Release 模式**的工具（僅 gopass 通過），同時順手清掉兩條 `Install-ScoopPackage` 死碼（curl/wget）。

Wave 3 規模刻意維持 Wave 1+2 等級小：1 個 external entry + 3 條 scoop install 行移除 + 1 個 migration script。不引入新模式（archive-pattern、env_set 等留給 Wave 4）。

## Goals / Non-Goals

**Goals**：
- gopass 脫離 scoop，改由 `.chezmoiexternal.toml` 管理至 `~/.local/bin/gopass.exe`
- 移除 dotfiles 不該管的 curl/wget 安裝（OS 內建或 Windows 流程未用）
- 跨機器 gopass 版本一致（git 為 source of truth）
- 既有機器無 PATH 變動（Wave 1 已搞定）
- corp-ssh-askpass 流程不受影響（gpg suite 維持 scoop 安裝）

**Non-Goals**：
- 自家 release mirror（supply-chain pinning）→ 沿用 `project_dotfiles_release_mirror.md`，所有 Wave 收尾後做
- archive-pattern 工具遷移（gpg/ffmpeg/nvm/vim）→ Wave 4 候選，待討論
- 純 scoop 清理（clink/dark/vimtutor/winget/winget-ps）→ 待後續討論
- 觸及 toolchain version managers（python/jdk/go/rustup/mvn）
- 觸及 GUI / Docker / 多版本工具

## Decisions

### D1: 只遷 gopass，不擴張範圍

剩餘 `Install-ScoopPackage` 呼叫已逐項評估。**唯一**符合 Wave 1+2 模式（單檔 binary + 穩定 GitHub Release URL + 受益於脫離 scoop shim）的是 gopass。其他要嘛根本不需要安裝（curl/wget），要嘛屬於不同模式（gpg/ffmpeg 是 multi-file archive、nvm/vim 需要 env vars 與 runtime dir）。

**Alternative considered**：把 archive-pattern 候選一起做。Reject——這會引入新的部署模式（`type = "archive"` + 自訂 PATH 條目 + 可能的 env_set），混在 Wave 3 會增加 review surface 與失敗風險，影響當前已穩定的 corp-ssh-askpass 流程。Wave 3 維持小範圍快速 ship，Wave 4 再單獨討論新模式。

### D2: gopass GitHub Release，archive `gopass-<ver>-windows-amd64.zip` 內取 `gopass.exe`

```
url    = "https://github.com/gopasspw/gopass/releases/download/v<ver>/gopass-<ver>-windows-amd64.zip"
path   = "gopass.exe"           # archive root，無子目錄
type   = "archive-file"
```

URL 模式內**有 `v` prefix 在 tag**，但 archive 內檔名版本字串**無 `v`**——已透過 `gh api` 與 `unzip -l` 實測 v1.16.1 確認。`$gopassVersion` 變數同時 inject 到 URL（含 `v`）與檔名（不含 `v`），與 golangci-lint 的雙重 inject 模式一致。

**Alternative considered**：直接從 scoop manifest 的 `https://github.com/gopasspw/gopass/releases/download/v$ver/gopass-windows-amd64-$ver.zip` 抓裸 .exe。Reject——gopass 上游沒有提供裸 `.exe` asset，只有 zip。

### D3: curl 直接移除，靠 OS-bundled fallback

`where.exe curl` 現況：
```
C:\Users\user\scoop\apps\git\2.54.0\mingw64\bin\curl.exe   ← Git Bash 帶
C:\Windows\System32\curl.exe                                ← Win10 1803+ OS-bundled
C:\Users\user\scoop\shims\curl.exe                          ← scoop（將移除）
```

Microsoft 自 Win10 build 17063（2018-04）將 curl 收進 System32，所以即便不裝 scoop 版，`curl` 也保證在 PATH 上。腳本流程中如有 `curl ...` 呼叫不受影響。

**不**改 `run_once_install-cli-tools.sh.tmpl`（Linux/macOS apt/brew 流程），那是其他 OS 的責任。

### D4: wget 直接移除，無 fallback 需求

dotfiles 全域 grep `\bwget\b` 過濾 openspec 後 6 個檔案：
- `run_once_install-cli-tools.ps1.tmpl` — 即將移除的安裝行
- `run_once_install-cli-tools.sh.tmpl` — Linux/macOS apt/brew 安裝行（不動）
- `run_onchange_install-03-claude-config.sh.tmpl` — `.sh.tmpl`（Linux/macOS），`curl || wget` fallback
- `.chezmoitemplates/rtk-config.toml` — RTK blacklist 文字標記，不是 require
- `docs/rtk.md` + `neovim/README.md` — 文件引述

**Windows `.ps1.tmpl` / PowerShell 流程內部沒有任何地方呼叫 wget**。直接刪除安裝呼叫即可，使用者實際需要時可手動 `scoop install wget` 或用 `Invoke-WebRequest`。

### D5: Wave 3 migration 腳本不做 PATH 重排序

延續 Wave 2 D4：Wave 1 的 `run_once_after_migrate-scoop-to-external.ps1.tmpl` 已 set User PATH 為 `~/.local/bin` 在 `~/scoop/shims` 之前。Wave 3 卸載的工具不需要再排一次。

新檔 `run_once_after_migrate-scoop-wave3.ps1.tmpl` 沿用 Wave 1+2 的 idempotent 模式：`scoop list <pkg>` 判定已安裝才 `scoop uninstall`，未安裝 no-op。

### D6: 保留 `gpg` 安裝行不動

`gpg` 是 corp-ssh-askpass Phase 2 依賴的核心工具。gpg suite（gpg.exe + gpg-agent.exe + gpgconf.exe + pinentry-basic.exe + 7 個 DLL）：
- 上游：gnupg.org NSIS `.exe`，**非 GitHub Release**
- scoop installer 有 side-effects：建立 `gpgconf.ctl`、copy gpg→gpg2、persist 處理 `$persist_dir/home`
- 屬於 archive-pattern + installer-script 混合形態

Wave 3 不碰，留作 Wave 4 候選獨立評估。

## Risks / Trade-offs

**[curl 從 scoop 8.19.0 fallback 到 System32 較舊版本]** → Windows 11 24H2 的 System32 curl 為 8.10.x，相比 scoop 落後 1-2 個 minor。Mitigation：日常 curl 使用（HTTPS GET、basic auth、JSON 上傳）兩版功能差距為零；若特殊需要新版可手動裝 scoop。

**[既有機器 scoop list 沒有 gopass 但有 corp-ssh-askpass 工作]** → 不可能，gopass 是 corp-ssh-askpass 工作流的必要工具，沒裝就根本沒在用。Mitigation：N/A。

**[chezmoi-external 下載 gopass 失敗造成 corp-ssh-askpass 中斷]** → 流程順序：
1. `chezmoi apply` 先處理 `.chezmoiexternal.toml` → 下載 gopass.exe
2. 之後跑 `run_once_after_migrate-scoop-wave3.ps1.tmpl` → 卸載 scoop gopass
3. 如果 step 1 失敗，step 2 不執行（PowerShell `$ErrorActionPreference = "Continue"` 在 migration script，但 chezmoi-external 失敗會中斷整個 apply）

Mitigation：URL 在 PR 中以 `gh api` 與 curl + unzip 雙重驗證；版本 pin 到具體版本而非 `latest`。

**[wget 移除後若有未發現的腳本使用]** → grep 過濾 openspec 後僅 6 處引用，全已分類。Mitigation：可逆——使用者隨時可手動 `scoop install wget`。

## Migration Plan

1. Implement: `.chezmoiexternal.toml` 新增 1 條 + version 變數；`run_once_install-cli-tools.ps1.tmpl` 移除 3 行；新增 `run_once_after_migrate-scoop-wave3.ps1.tmpl`
2. 當前機器 `chezmoi apply -v` 確認：
   - `~/.local/bin/gopass.exe` 存在且 `gopass --version` 正確
   - scoop 卸載 3 個 entries（gopass + curl + wget）
   - PATH 不變
   - `gpg --version` 仍正常（gpg suite 維持 scoop 安裝）
   - corp-ssh-askpass：`gopass show <path>` 仍能成功（驗證 gopass 能呼叫 gpg-agent）
3. `openspec validate scoop-external-wave3 --strict`
4. Squash/normal merge
5. SSH session 驗證（透過 Tailscale 從另一台 SSH 進來）：`gopass --version` 與 `gopass show <path>` 仍可運作（無 scoop shim 雷）
