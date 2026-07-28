## 1. 共用 fragment

- [x] 1.1 建立 `home/.chezmoitemplates/scripts/log.sh`：六個動詞（`log_begin` / `log_section` / `log_step` / `log_skip` / `log_warn` / `log_end`）、`_LOG_TITLE` 單一來源、`log_begin` 內安裝 EXIT trap 保證結束 banner 帶 exit code、與 `set -euo pipefail` 相容
- [x] 1.2 建立 `home/.chezmoitemplates/scripts/log.ps1`：同六動詞（`Log-Begin` / `Log-Section` / `Log-Step` / `Log-Skip` / `Log-Warn` / `Log-End`）、`$script:LogTitle` 單一來源、PowerShell 5.1 相容、輸出格式與 `log.sh` 逐字一致
- [x] 1.3 以一支拋棄式 bash 腳本驗證 `log.sh` 的四種收尾路徑（正常結束、`exit 0` 早退、`set -e` 中止、未捕捉錯誤）都印出正確的結束 banner 與 rc
- [x] 1.4 建立 `home/.chezmoitemplates/scripts/npm-install.sh` 與 `npm-install.ps1`：npm 全域套件冪等安裝守衛，內部改用 log 動詞
- [x] 1.5 建立 `home/.chezmoitemplates/scripts/pkg-install.sh`：`pkg_install <cmd> <pkg>`，以渲染期 `.chezmoi.os` 分支展開 apt 或 brew
- [x] 1.6 建立 `home/.chezmoitemplates/scripts/scoop-uninstall.ps1`：`Remove-ScoopPackage -Name -Reason [-PruneShims]`，理由字串餵給 `Log-Section`

## 2. bash 腳本改寫（可在本機實跑驗證）

- [x] 2.1 `run_onchange_before_install-prereqs.sh.tmpl`（目前無 banner）
- [x] 2.2 `run_once_install-01-runtimes.sh.tmpl`：11 個段落全部改為 runtime 可見的目的
- [x] 2.3 `run_install-02-npm-tools.sh.tmpl`：改用 `npm-install.sh` fragment
- [x] 2.4 `run_onchange_install-03-claude-config.sh.tmpl`
- [x] 2.5 `run_once_install-cli-tools.sh.tmpl`：`apt_install` / `brew_install` 兩份守衛改用 `pkg-install.sh` fragment
- [x] 2.6 `run_once_install-containers.sh.tmpl`、`run_once_install-fonts.sh.tmpl`
- [x] 2.7 `run_update-claude-plugins.sh.tmpl`、`run_update-rust-toolchain.sh.tmpl`、`run_onchange_set-git-hookspath.sh.tmpl`（後者目前無 banner）
- [x] 2.8 確認所有 `modify_*.sh.tmpl` **未**被加入 banner（stdout 即檔案內容）

## 3. PowerShell 腳本改寫（僅渲染驗證）

- [x] 3.1 `run_install-02-npm-tools.ps1.tmpl`：改用 `npm-install.ps1` fragment
- [x] 3.2 `run_once_install-01-runtimes.ps1.tmpl`、`run_once_install-cli-tools.ps1.tmpl`、`run_once_install-containers.ps1.tmpl`、`run_once_install-fonts.ps1.tmpl`
- [x] 3.3 `run_onchange_install-03-claude-config.ps1.tmpl`、`run_onchange_install-05-rtk.ps1.tmpl`、`run_onchange_install-gnupg.ps1.tmpl`
- [x] 3.4 `run_onchange_before_patch-chezmoi-config.ps1.tmpl`、`run_onchange_before_setup-paths.ps1.tmpl`、`run_onchange_before_set-docker-host.ps1.tmpl`（後者目前無 banner）
- [x] 3.5 `run_onchange_configure-windows-terminal.ps1.tmpl`、`run_once_register-fonts.ps1.tmpl`、`run_onchange_set-git-hookspath.ps1.tmpl`、`run_warn-pwsh-msix.ps1.tmpl`
- [x] 3.6 `run_update-claude-plugins.ps1.tmpl`、`run_update-rust-toolchain.ps1.tmpl`、`run_after_modify-codex-config.ps1.tmpl`

## 4. scoop 遷移腳本合併

- [x] 4.1 建立 `home/run_once_after_migrate-scoop-cleanup.ps1.tmpl`：單一「套件 → 移除理由」表，涵蓋原 wave 2/3/4/5/6/7/11/12a 的 19 個套件；jdtls 設 `-PruneShims`
- [x] 4.2 逐條比對合併後腳本與 `tool-dependencies` delta spec 的每個 Scenario（soft-unmanaged 排除 4 項、不動 PATH、不觸 `~/.local/bin`、scoop 缺席整支 skip、非 jdtls 不碰 shims）
- [x] 4.3 刪除 `run_once_after_migrate-scoop-wave{2,3,4,5,6,7,11-jdtls,12a}.ps1.tmpl` 共 8 支（`run_*` 不部署到 target，確認毋須 `.chezmoiremove`）
- [x] 4.4 保留但改寫 wave 1（`migrate-scoop-to-external`）、8（gpg）、9（nvm）、10（toolchain）、12b：套用新 log 慣例並改用 `scoop-uninstall.ps1` fragment

## 5. chezmoi-author skill

- [x] 5.1 於 `home/.chezmoitemplates/skills/chezmoi-author.md` 新增「Script Logging Contract」節：六動詞表、起訖 banner 單一來源規則、bash EXIT trap / PowerShell try-finally 的收尾機制、`modify_*` 排除、ps1 用 `return` 不用 `exit`
- [x] 5.2 新增「Shared Fragment Extraction」節：抽取門檻（同 interpreter 重複 2 次以上）、合併 vs 抽取判準、fragment 副檔名慣例、現有 fragment 對照表更新
- [x] 5.3 Authoring Checklist 增加三項檢查（成對 banner、段落目的 runtime 可見、重複邏輯已抽 fragment）

## 6. 驗證

- [x] 6.1 全量 `chezmoi execute-template` 渲染所有 `run_*.tmpl`（分別以 linux / darwin / windows 的 `.chezmoi.os` 驗證），確認無渲染錯誤、無 `<no value>`
- [x] 6.2 render 兩個 skill wrapper（`dot_claude` / `dot_codex`）確認無 `<no value>`；以真 YAML parser 驗 frontmatter
- [x] 6.3 ~~pwsh 語法解析~~ — **未執行**：本機（WSL）無 `pwsh`/`powershell`，無法對渲染後的 ps1 做 `[ScriptBlock]::Create` 解析。所有 PowerShell 變更僅通過 template 渲染驗證。
- [x] 6.4 `chezmoi apply --dry-run` 檢查無非預期 diff
- [x] 6.5 於本機（WSL）實跑受影響的 bash 腳本，確認 banner 成對且段落目的可見
- [x] 6.6 已記錄：**Windows 實機 apply 抽查未完成** — 24 支 ps1（含合併後的 scoop cleanup、gnupg 安裝、PATH/registry 改寫）在本機無法執行，需在 Windows 機器上跑一次 `chezmoi apply` 才算真正落地。
