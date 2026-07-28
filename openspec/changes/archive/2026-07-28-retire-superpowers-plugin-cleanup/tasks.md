## 1. 本機基準（已完成）

- [x] 1.1 稽核依賴:確認 `~/.claude/skills/`、`dev-workflow`、`~/.claude/CLAUDE.md`、chezmoi source 皆無 `superpowers:*` 引用;確認 episodic-memory 僅共用 `~/.config/superpowers/` 目錄名而非依賴 plugin
- [x] 1.2 本機執行 `claude plugin uninstall superpowers@claude-plugins-official` 並驗證 marketplace、episodic-memory、elements-of-style 不受影響
- [x] 1.3 本機刪除 `~/.claude/commands/opsx/workflow.md` 孤兒（備份留存）與 `~/.claude/plugins/cache/claude-plugins-official/superpowers`（4.2 MB）

## 2. Unix 腳本（.sh.tmpl）

- [x] 2.1 `home/run_onchange_install-03-claude-config.sh.tmpl`:在 plugin 區塊加入條件式 uninstall — 沿用既有 `INSTALLED_PLUGINS` grep 慣例,命中 `superpowers@claude-plugins-official` 才執行 uninstall
- [x] 2.2 同檔 cleanup 區塊:於既有 `superpowers-marketplace/superpowers` 之後增補 `claude-plugins-official/superpowers` 的 `rm -rf`（保留既有行）
- [x] 2.3 驗證:`chezmoi execute-template < 該檔` 渲染成功且 `bash -n` 語法檢查通過

## 3. Windows 腳本（.ps1.tmpl）

- [x] 3.1 `home/run_onchange_install-03-claude-config.ps1.tmpl`:parity 加入同樣的條件式 uninstall
- [x] 3.2 同檔 cleanup 區塊:parity 增補 `claude-plugins-official\superpowers` 的 `Remove-Item`（保留既有 block）
- [x] 3.3 驗證(部分):本機無 pwsh 且 template OS 守衛使其在 Linux 渲染為空 — 僅完成人工 parity 比對,實際執行待 Windows 機器 apply 確認

## 4. 退役 command 修剪

- [x] 4.1 `home/.chezmoiremove` 加入 `.claude/commands/opsx/workflow.md`,附註說明其為 `dev-workflow` skill 取代的孤兒

## 5. 文件同步

- [x] 5.1 `docs/claude-code.md`:更新 line 43-46 附近的歷史脈絡段,說明移除已由 `run_onchange_` 腳本跨機器收斂（原措辭僅稱「已移除」,未涵蓋傳播）

## 6. 驗收

- [x] 6.1 `chezmoi diff` 確認僅預期變更,無非預期 diff
- [x] 6.2 `chezmoi apply` 執行腳本,確認在「plugin 已不存在」的本機重跑不報錯、後續 jdtls/MCP/episodic-memory 段正常完成
- [x] 6.3 `openspec validate retire-superpowers-plugin-cleanup --strict` 通過
- [x] 6.4 grep 全 repo 確認無殘留的 superpowers plugin 安裝指令（marketplace / episodic / elements-of-style 引用應保留）
