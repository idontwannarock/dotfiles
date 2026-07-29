## 1. 修復 scoopupdate（slice 1）

- [x] 1.1 `git mv scripts/scoop-interactive-update.ps1 home/dot_local/bin/`，確認 `scripts/` 已空並移除
- [x] 1.2 更新 `docs/user-scripts.md`：腳本位置由 `scripts/` 改為 `home/dot_local/bin/`（部署到 `~/.local/bin/`），並補上同目錄既有的 `switch-pwsh-to-msi.ps1` 使清單反映實況
- [x] 1.3 更新 `home/.chezmoitemplates/skills/chezmoi-author/windows.md` 中 `scripts/scoop-interactive-update.ps1` 的路徑引用
- [x] 1.4 `grep -rn "scripts/scoop\|root 的 scripts\|scripts/ " --include=*.md .` 確認無殘留舊路徑引用（`.github/scripts/` 與 `.chezmoitemplates/scripts/` 是不同的東西，不得誤改）；一併移除 `README.md` 目錄樹的 `scripts/` 一行與文件表格的失效描述
- [x] 1.5 **（實作中發現，design 未預見）** 加 `.chezmoiignore.tmpl` 的 Windows-only 守衛：腳本搬進 `home/` 後在 Linux/macOS 也會被部署，但 scoop 是 Windows 專屬。併入既有的 `switch-pwsh-to-msi.ps1` 守衛區塊，spec delta 補上對應 requirement 與 scenario
- [ ] 1.6 驗證：在 Windows 上 `chezmoi apply` 後，`~/.local/bin/scoop-interactive-update.ps1` 存在且 `scoopupdate` alias 可解析並執行（依專案規則，先在實機確認再收）

## 2. Pester 測試進 CI（slice 2）

- [x] 2.1 新增 `.github/workflows/test-pester.yml`：`windows-latest` runner，觸發於 pull_request（見 6.3：初版含 push，review 後改為 PR-only），`paths` 限定 `tests/**`、`home/dot_local/bin/**`、workflow 自身
- [x] 2.2 workflow 執行 `Invoke-Pester -Path tests -CI`（`-CI` 使失敗回非零 exit code）；不倚賴 runner 內建版本，明確加上 `Install-Module Pester -MinimumVersion 5.5.0` 前置步驟
- [x] 2.3 驗證：PR #35 觸發 `Test PowerShell (Pester)` run 30413199779，conclusion=success，`Tests Passed: 9, Failed: 0`。首跑即綠，無 stale 測試也無 helper bug
- [x] 2.4 更新 `README.md` 的 `tests/` 說明，標明由 CI 執行

## 3. 編譯來源收攏至 tools/（slice 3）

- [x] 3.1 `git mv claude/statusline tools/statusline` 與 `git mv passgen tools/passgen`，確認 root 的 `claude/` 已空並移除；此 commit 只搬移不改內容，保住 git rename detection
- [x] 3.2 更新 `.github/workflows/release-statusline.yml` 三處路徑：`paths` filter、`working-directory`、artifact `path`
- [x] 3.3 更新 `.github/workflows/release-passgen.yml` 的 `paths`、`workspaces`、兩處 `working-directory`、artifact `path`
- [x] 3.4 更新 `README.md` 目錄樹：`claude/statusline/` 與 `passgen/` 兩行併為 `tools/` 區塊
- [x] 3.5 更新 `docs/claude-code.md` 兩處 `claude/statusline/` 引用（檔首的目錄說明、cache writer 表格）
- [x] 3.6 `grep -rn "claude/statusline\|passgen/" . --exclude-dir=.git --exclude-dir=archive` 確認除 `openspec/changes/` 本次文件與已封存內容外無殘留。**此 pattern 不足**：review 抓到 `docs/claude-code.md:324` 的 `cp statusline/statusline.go`（相對路徑，不含 `claude/` 前綴故無法被匹配）。已補掃 `statusline/statusline\.go\|cp statusline/` 並修正
- [ ] 3.7 驗證：`release-statusline.yml` 與 `release-passgen.yml` 皆實際觸發（若未觸發即代表 `paths` filter 改漏——這是本 slice 最主要的風險）。**只能於 merge 後驗證**：兩支 workflow 的 trigger 是 `push` 到 `main`，PR 不會觸發；`tools/passgen` 的 Rust build 同樣要等到那時才第一次被編譯

## 4. 移除已棄用的 neovim/（slice 4）

- [x] 4.1 讀過 `neovim/` 內容，確認無尚未搬移到別處的有效設定（`init.lua` 指向的 `lua/` 模組、`.gitignore`）
- [x] 4.2 `git rm -r neovim/`
- [x] 4.3 更新 `README.md`：移除目錄樹中的 `neovim/` 一行，並處理棄用表格中 `NeoVim（neovim/）| 已棄用` 該列（改為說明已移除，或整列刪除）

## 5. 收尾

- [x] 5.1 `openspec validate repo-root-layout` 通過
- [x] 5.2 全 repo 掃描確認 root 只剩：工具強制位置、`docs/`、`tests/`、`tools/`、`README.md` 與根層設定檔
- [x] 5.3 `verify-done`：列出實際執行過的驗證命令與輸出，未在 Windows 實機驗證的項目明確標示為未驗證

## 6. Review 修正（code-reviewer + code-simplifier，PR #35）

- [x] 6.1 `docs/claude-code.md`：`cp statusline/statusline.go` 為搬移前的相對路徑；同時該段 `go build -o statusline.exe statusline.go` 本身就是壞的（`statusline.go` 依賴 build-tag 分流的 `count_unix.go`/`count_windows.go`，單檔編譯得到 `undefined: countClaudeProcesses`）。整段改為 `cd tools/statusline && go build -o ~/.claude/statusline .`
- [x] 6.2 移除 `scoop-interactive-update.ps1` 檔首的 UTF-8 BOM，與同目錄另兩支 `.ps1` 一致（BOM 自舊位置繼承，非本次新增；`ed9712e` 已確立本 repo 清 BOM 的慣例）
- [x] 6.3 `test-pester.yml` 改為 PR-only（`pull_request: branches: [main]`），對齊唯一的同類純檢查 workflow `validate-externals.yml`；連帶消除 `paths` 在兩個 trigger 間逐字重複。spec delta 同步改寫
- [x] 6.4 移除 `Import-Module Pester -MinimumVersion 5.5.0`：autoloading 已解析到最高可用版本，`-MinimumVersion` 於 import 不提供額外保證
- [x] 6.5 兩支 skill 文件（`chezmoi-author.md`、`chezmoi-author/windows.md`）原斷言「`.ps1` 一律 CRLF」，未提 `home/dot_local/bin/*` 的 LF 覆蓋——本次正好往該目錄放進一支 `.ps1`，補上例外說明
- [x] 6.6 `.gitattributes` 該規則的註解仍寫「Shell scripts without extension」，與現況（`.ps1` + 20 餘個 `.cmd`）不符且會誤導後續編輯，改寫為明示「刻意覆蓋副檔名規則」
- [x] 6.7 `.gitignore` 加 `testResults.xml`（`Invoke-Pester -CI` 會寫出 JUnit 報告）；`README.md` 的 `.github/workflows/` 說明補上 Pester 與 externals 驗證
