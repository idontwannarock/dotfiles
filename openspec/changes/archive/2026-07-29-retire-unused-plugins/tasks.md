## 1. PowerShell 版改寫

- [x] 1.1 在 `run_onchange_install-03-claude-config.ps1.tmpl` 以 `$retiredPlugins`（id → 理由）資料表取代單一 superpowers `if`，uninstall 迴圈先比對已取得的 `$installedPlugins` 快照
- [x] 1.2 cache 清理改為迴圈，路徑由 id 推導為 `plugins\cache\<marketplace>\<id>`；額外保留 `superpowers-marketplace\superpowers` 的防禦性清理
- [x] 1.3 確認 log 行印出**理由**而非 id，符合腳本 logging 契約

## 2. Bash 版改寫

- [x] 2.1 `run_onchange_install-03-claude-config.sh.tmpl` 比照，控制流與 ps1 版逐字對應，僅語法不同
- [x] 2.2 兩份退役清單內容一致（以 spec 表為單一事實來源逐項核對）

## 3. skill 與文件

- [x] 3.1 `chezmoi-author.md` 新增退役慣例：退役 plugin = 加進退役表，不是刪掉安裝那行——與既有 `.chezmoiremove` 條目並列
- [x] 3.2 `docs/claude-code.md` 補上退役清單與其理由

## 4. 驗證

- [x] 4.1 兩支腳本經 `chezmoi execute-template` 渲染成功
- [x] 4.2 渲染後的 bash 版通過 `bash -n` 語法檢查
- [x] 4.3 **未驗**：此 WSL 無 pwsh，無法跑 PowerShell parser。改以強制 windows 分支渲染（312 行）+ 括號/引號平衡檢查（`{}` 79/79、`()` 88/88、`[]` 51/51）作為替代，但**不等於** parser 驗證
- [x] 4.4 退役清單的 11 筆在 ps1 / sh / spec 三處完全一致（以指令比對，非肉眼）
- [x] 4.5 確認 4 個仍在使用的 plugin 不在退役清單中（slack、explanatory-output-style、episodic-memory、elements-of-style），且手動安裝的 `code-review` 也不在
- [x] 4.6 `openspec validate retire-unused-plugins` 通過
- [x] 4.7 `chezmoi apply --dry-run` exit 0
- [x] 4.8 `verify-done`：列出實際執行的命令與輸出；真正的行為驗證（plugin 被移除）需在實機 apply，明確標示為未驗
