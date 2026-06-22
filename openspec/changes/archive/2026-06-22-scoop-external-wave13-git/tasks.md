# Tasks — Wave 13: git-bash interpreter 移出 scoop（偵測式，scope A）

> 先在本機驗證再改 source。本機現有 scoop git;遷移＝winget 裝 git → 偵測改走 Program Files git → 驗證 apply。

## 1. git-bash 偵測
- [x] 1.1 `.chezmoi.toml.tmpl` `[interpreters.sh]`：以 static 候選清單（`~/.local/opt/git` → `C:\Program Files\Git` → `~/scoop/apps/git/current`）`stat`-based first-existing 取 `bin\bash.exe`，取代硬指 scoop 路徑。
- [x] 1.2 `run_onchange_before_patch-chezmoi-config.ps1.tmpl`：同清單（PS）+ `HKLM/HKCU\SOFTWARE\GitForWindows\InstallPath` registry probe；解析 git-bash、self-heal config interpreter；guard 改檢查偵測路徑。
- [x] 1.3 本機驗證：`winget install Git.Git` 後 `chezmoi init` 重 render，interpreter＝Program Files git；`chezmoi execute-template < .chezmoi.toml.tmpl` 確認。

## 2. 重指另外 2 處 functional refs
- [x] 2.1 `dot_claude/modify_settings.json.sh.tmpl`：`git_bash` arg 改用同 `stat` 清單算出的 bash 路徑（取代 scoop 路徑）。
- [x] 2.2 `run_onchange_install-gnupg.ps1.tmpl`：`$pinentryW32` 改由同清單算出 `<git root>\usr\bin\pinentry-w32.exe`，無 git 時維持 fallback 至 `pinentry-basic.exe`。
- [x] 2.3 本機驗證：apply 後 settings.json 的 git_bash 指向新 git；gpg-agent.conf 的 pinentry 指向新 git 的 pinentry-w32。

## 3. README bootstrap + dos2unix 提示
- [x] 3.1 `README.md` Windows bootstrap：移除「git 一律透過 scoop」前提 + `scoop install git`/`scoop install chezmoi`，改 `winget install Git.Git` + `winget install twpayne.chezmoi`；scoop 降為「選用：GUI app」。
- [x] 3.2 `run_onchange_install-03-claude-config.ps1.tmpl:98`：dos2unix 找不到時的提示由 `scoop install dos2unix` 改為「重跑 `chezmoi apply`」。

## 4. 本機遷移與整體驗證
- [x] 4.1 `winget install Git.Git`（裝到 Program Files）。
- [x] 4.2 `chezmoi init` + `chezmoi apply`：全程走新 git bash，`.sh`/modify_/run scripts 全綠;確認 interpreter、settings.json、gpg pinentry 皆指向非-scoop git。
- [x] 4.3 確認偵測順序正確（Program Files 勝過 scoop）;scoop git 留著但不再被引用（**不** `scoop uninstall git`）。

## 5. 收尾
- [x] 5.1 `openspec validate scoop-external-wave13-git --strict` 通過。
- [x] 5.2 commit 只 stage 本輪相關檔案。
