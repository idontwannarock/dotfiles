## 1. localfiles helper

- [x] 1.1 撰寫 `dot_local/bin/executable_localfiles`(POSIX sh):repo-id 推導(`basename(dirname(realpath(git-common-dir)))`)、branch 解析(`symbolic-ref --short -q`,detached→`_default`)、桶解析(branch→_default)、被管理清單(`.env .env.local .env.*.local`,頂層)
- [x] 1.2 子命令 `restore`(只填補缺檔,不覆寫)、`backup [--branch]`(_default 或 branch 桶)、`where`(印 store 路徑);非 git repo:restore 安靜退出、backup 報錯
- [x] 1.3 在本機實測:於暫存 repo 建 `.env`、`localfiles backup`、刪除後 `localfiles restore` 補回;已存在時不覆寫;`--branch` 寫進 branch 桶且 restore 優先採用

## 2. 全域 dispatcher hook

- [x] 2.1 撰寫 `dot_config/git/hooks/executable_post-checkout`(POSIX sh):先 `localfiles restore`(失敗不阻斷),再 chain `<toplevel>/.githooks/post-checkout` 與 `<git-common-dir>/hooks/post-checkout`,realpath 比對防自我遞迴
- [x] 2.2 本機實測:設 `core.hooksPath` 指向部署後目錄,`git checkout`/`worktree add` 觸發 restore;放一個 `.githooks/post-checkout` 確認仍被 chain

## 3. 一次性安裝(global core.hooksPath)

- [x] 3.1 `run_onchange_set-git-hookspath.sh.tmpl`(`{{ if ne .chezmoi.os "windows" }}` gate):讀既有 `core.hooksPath`,已是目標則跳過、為其他值印警告不覆蓋、未設則設為絕對 `~/.config/git/hooks`
- [x] 3.2 `run_onchange_set-git-hookspath.ps1.tmpl`(`{{ if eq .chezmoi.os "windows" }}` gate):同邏輯,路徑用 `$env:USERPROFILE/.config/git/hooks`(正斜線)
- [x] 3.3 確認 `.chezmoiignore.tmpl` 不排除新檔(三平台都要)、`.gitattributes` 對 sh hook/helper 採 LF

## 4. Reference 文件

- [x] 4.1 `dot_agent/reference/local-files/index.md`:概念、store 佈局、被管理清單、restore/backup 語意(全域=備份/in-folder=source)、per-branch 桶規則、**agent read-fallback 規則**
- [x] 4.2 `dot_agent/reference/local-files/setup.md`:一次性安裝(global hooksPath + dispatcher + helper 皆 chezmoi)、驗證方式、現有 bare repo 遷移(`--unset core.hooksPath`)、Windows 註記
- [x] 4.3 `bare-worktree/setup.md`:收掉 `git --git-dir=.bare config core.hooksPath .githooks` 那行,改述依賴全域 dispatcher 並交叉連結 `local-files/`
- [x] 4.4 `bare-worktree/claude-state.md`:更新「`.env` 無法自動補齊」一節為指向 local-files 補齊機制

## 5. chezmoi 驗證

- [x] 5.1 `chezmoi diff` 確認 `~/.agent/reference/local-files/*.md`、`~/.local/bin/localfiles`、`~/.config/git/hooks/post-checkout` 將生成且具可執行位
- [x] 5.2 `chezmoi apply` 後實測:`localfiles` 在 PATH 可執行;`git config --global core.hooksPath` 指向部署目錄;在一個測試 repo 觸發 checkout 確認 restore 生效
- [x] 5.3 確認設定 global hooksPath 後,一個有自家 `.git/hooks/post-checkout` 的 repo 仍被 dispatcher chain(不靜默破壞)
