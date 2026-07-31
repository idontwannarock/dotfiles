## 1. 拔除註冊與部署（單次 apply 必須一起生效）

- [x] 1.1 `home/dot_claude/modify_settings.json.sh.tmpl`：`.hooks.PreToolUse` 的 hard-assign 改為外科式 `map(select(test("rtk-rewrite") | not))` + 空陣列時 `del`；同步更新檔頭註解（從「同步的欄位」移到「主動刪除」清單）
- [x] 1.2 `home/.chezmoiremove` 新增 rtk 段落，點名 `.claude/hooks/rtk-rewrite.sh`、`.config/rtk`、`AppData/Roaming/rtk`、`AppData/Local/rtk`、`.local/bin/rtk`、`.local/bin/rtk.exe`、`.cache/rtk-hook-version-ok`，並附上退役理由註解（比照檔內既有風格）
- [x] 1.3 刪除 source：`home/dot_claude/hooks/executable_rtk-rewrite.sh`、`home/run_onchange_install-05-rtk.ps1.tmpl`、`home/dot_config/rtk/`、`home/.chezmoitemplates/rtk-config.toml`
- [x] 1.4 `home/.chezmoiexternal.toml`：移除 rtk binary 區塊（含 `# renovate:` 註解與 `$rtkVersion` / `$rtkAsset` 變數）
- [x] 1.5 `home/.chezmoiignore.tmpl`：移除 `.config/rtk` 的 Windows 排除區塊

## 2. 本機驗證（依專案慣例：先在當前電腦確認生效）

- [x] 2.1 `chezmoi diff` 檢查變更範圍符合預期，無非預期的檔案異動
- [x] 2.2 `chezmoi apply` 後確認 `~/.claude/hooks/rtk-rewrite.sh`、`~/.config/rtk`、`~/.local/bin/rtk` 皆不存在
- [x] 2.3 確認 `~/.claude/settings.json` 內無 `rtk` 字樣，且 `UserPromptSubmit` / `SessionStart` 註冊完好
- [x] 2.4 再跑一次 `chezmoi apply` 確認冪等（第二次無 diff）
- [x] 2.5 新 Claude Code session 執行一次 Bash 指令，確認輸出為 raw（不再有 rtk 摘要）且無 hook 錯誤

## 3. 文件

- [x] 3.1 刪除 `docs/rtk.md`
- [x] 3.2 `README.md` 移除工具表中的 RTK 一列
- [x] 3.3 `docs/claude-code.md` 移除 RTK 章節

## 4. 收尾

- [x] 4.1 `openspec validate remove-rtk --strict` 通過
- [x] 4.2 全 repo `grep -ri rtk`（排除 `openspec/changes/`）無殘留引用
