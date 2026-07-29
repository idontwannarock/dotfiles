## 1. 修復 scoopupdate（slice 1）

- [x] 1.1 `git mv scripts/scoop-interactive-update.ps1 home/dot_local/bin/`，確認 `scripts/` 已空並移除
- [x] 1.2 更新 `docs/user-scripts.md`：腳本位置由 `scripts/` 改為 `home/dot_local/bin/`（部署到 `~/.local/bin/`），並補上同目錄既有的 `switch-pwsh-to-msi.ps1` 使清單反映實況
- [x] 1.3 更新 `home/.chezmoitemplates/skills/chezmoi-author/windows.md` 中 `scripts/scoop-interactive-update.ps1` 的路徑引用
- [x] 1.4 `grep -rn "scripts/scoop\|root 的 scripts\|scripts/ " --include=*.md .` 確認無殘留舊路徑引用（`.github/scripts/` 與 `.chezmoitemplates/scripts/` 是不同的東西，不得誤改）；一併移除 `README.md` 目錄樹的 `scripts/` 一行與文件表格的失效描述
- [x] 1.5 **（實作中發現，design 未預見）** 加 `.chezmoiignore.tmpl` 的 Windows-only 守衛：腳本搬進 `home/` 後在 Linux/macOS 也會被部署，但 scoop 是 Windows 專屬。併入既有的 `switch-pwsh-to-msi.ps1` 守衛區塊，spec delta 補上對應 requirement 與 scenario
- [ ] 1.6 驗證：在 Windows 上 `chezmoi apply` 後，`~/.local/bin/scoop-interactive-update.ps1` 存在且 `scoopupdate` alias 可解析並執行（依專案規則，先在實機確認再收）

## 2. Pester 測試進 CI（slice 2）

- [x] 2.1 新增 `.github/workflows/test-pester.yml`：`windows-latest` runner，觸發於 push to main 與 pull_request，`paths` 限定 `tests/**`、`home/dot_local/bin/**`、workflow 自身
- [x] 2.2 workflow 執行 `Invoke-Pester -Path tests -CI`（`-CI` 使失敗回非零 exit code）；不倚賴 runner 內建版本，明確加上 `Install-Module Pester -MinimumVersion 5.5.0` 前置步驟
- [ ] 2.3 驗證：push 後 workflow 實際觸發並跑完。首跑若為紅色，判定是測試 stale 還是 `corp-ssh-askpass.ps1` 有真 bug，修對應的一邊——不得刪測試換綠燈
- [x] 2.4 更新 `README.md` 的 `tests/` 說明，標明由 CI 執行

## 3. 編譯來源收攏至 tools/（slice 3）

- [x] 3.1 `git mv claude/statusline tools/statusline` 與 `git mv passgen tools/passgen`，確認 root 的 `claude/` 已空並移除；此 commit 只搬移不改內容，保住 git rename detection
- [x] 3.2 更新 `.github/workflows/release-statusline.yml` 三處路徑：`paths` filter、`working-directory`、artifact `path`
- [x] 3.3 更新 `.github/workflows/release-passgen.yml` 的 `paths`、`workspaces`、兩處 `working-directory`、artifact `path`
- [x] 3.4 更新 `README.md` 目錄樹：`claude/statusline/` 與 `passgen/` 兩行併為 `tools/` 區塊
- [x] 3.5 更新 `docs/claude-code.md` 兩處 `claude/statusline/` 引用（檔首的目錄說明、cache writer 表格）
- [x] 3.6 `grep -rn "claude/statusline\|passgen/" . --exclude-dir=.git --exclude-dir=archive` 確認除 `openspec/changes/` 本次文件與已封存內容外無殘留
- [ ] 3.7 驗證：push 後 `release-statusline.yml` 與 `release-passgen.yml` 皆實際觸發（若未觸發即代表 `paths` filter 改漏——這是本 slice 最主要的風險）

## 4. 移除已棄用的 neovim/（slice 4）

- [x] 4.1 讀過 `neovim/` 內容，確認無尚未搬移到別處的有效設定（`init.lua` 指向的 `lua/` 模組、`.gitignore`）
- [x] 4.2 `git rm -r neovim/`
- [x] 4.3 更新 `README.md`：移除目錄樹中的 `neovim/` 一行，並處理棄用表格中 `NeoVim（neovim/）| 已棄用` 該列（改為說明已移除，或整列刪除）

## 5. 收尾

- [x] 5.1 `openspec validate repo-root-layout` 通過
- [x] 5.2 全 repo 掃描確認 root 只剩：工具強制位置、`docs/`、`tests/`、`tools/`、`README.md` 與根層設定檔
- [ ] 5.3 `verify-done`：列出實際執行過的驗證命令與輸出，未在 Windows 實機驗證的項目明確標示為未驗證
