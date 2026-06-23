## 1. 改 Windows Terminal Git Bash profile（本機）

- [x] 1.1 備份本機 WT settings.json，把「Git Bash」profile 的 `commandline` 從 `~\scoop\apps\git\current\bin\bash.exe` 改為 `C:\Program Files\Git\bin\bash.exe`
- [x] 1.2 開新「Git Bash」分頁驗證可正常開啟，且 `which bash` / `git --version` 指向 Program Files git

## 2. 卸載 scoop git（本機，難逆）

- [x] 2.1 動手前再跑一次 PATH 模擬確認安全（git→Program Files、gpg/ssh 不變、sh 消失為預期）
- [x] 2.2 執行 `scoop uninstall git`
- [x] 2.3 確認 `scoop list` 不再含 `git`

## 3. 驗證（全新 shell）

- [x] 3.1 全新登入 shell：`where.exe git` 第一個為 `C:\Program Files\Git\cmd\git.exe`
- [x] 3.2 `where.exe gpg` → `~\.local\opt\gnupg\bin`；`where.exe ssh` → `System32\OpenSSH`
- [x] 3.3 Windows Terminal「Git Bash」分頁仍可開啟；`git --version` 正常（以直接執行 profile commandline 驗證；gpg-agent `alive`）
- [x] 3.4 gpg 簽章鏈完整：`pinentry-program` → Program Files `usr\bin\pinentry-w32.exe`（存在）；standalone gnupg 自帶 gpg-agent/gpgconf；git 未啟用 commit 簽章故無退化。額外清理：移除 scoop 卸載殘留的 User PATH 孤兒 `scoop\apps\git\current\bin`

## 4. 收尾紀錄

- [x] 4.1 更新 memory：`scoop-git-path-migration-todo` 標記完成（刪除並以 `scoop-git-interactive-removed` 取代）
- [x] 4.2 更新 memory：新增「chezmoi 管理 WT Git Bash profile」future TODO（`wt-gitbash-profile-chezmoi-todo`）
