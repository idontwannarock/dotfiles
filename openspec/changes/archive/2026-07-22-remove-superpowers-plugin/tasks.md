## 1. 本機驗證(test-first)

- [x] 1.1 記錄 baseline:確認 `superpowers@claude-plugins-official` 現已安裝,episodic-memory sync log 可寫入
- [x] 1.2 本機執行 `claude plugin uninstall superpowers@claude-plugins-official`
- [x] 1.3 驗證 episodic-memory 仍運作(sync CLI 可跑、conversation-archive 完整、search 可用),確認 §8 前提已證偽

## 2. 移除安裝來源(chezmoi source)

- [x] 2.1 `home/run_onchange_install-03-claude-config.sh.tmpl`:移除 `claude plugin install superpowers`(含其 echo 行);保留 marketplace add、slack、episodic-memory、elements-of-style 與 cache cleanup rm
- [x] 2.2 `home/run_onchange_install-03-claude-config.ps1.tmpl`:parity 移除對應的 superpowers install 兩行;保留其餘
- [x] 2.3 確認兩腳本的 `rm -rf .../superpowers-marketplace/superpowers` cache cleanup 原樣保留

## 3. 移除文件與護欄

- [x] 3.1 `home/.chezmoitemplates/user-system-prompt.md`:刪除 §8「Superpowers 過渡護欄」整節,重編號(此處 §8 為最後一節,確認無後續章節需改號)
- [x] 3.2 `docs/claude-code.md`:plugin 表移除 superpowers 列;修訂歷史脈絡段(line 43-46 附近)中「plugin 目前仍安裝但…移除待驗證」措辭為「已移除」
- [x] 3.3 `~/.claude/CLAUDE.md` §8(全域指令,dotfiles 外部):移除過渡護欄段

## 4. 驗收

- [x] 4.1 `chezmoi apply`(或 `chezmoi diff`)確認 install 腳本 diff 符合預期、冪等、無非預期變更
- [x] 4.2 `openspec validate remove-superpowers-plugin --strict` 通過
- [x] 4.3 grep 全 repo 確認無殘留的 superpowers plugin 安裝指令或過渡護欄引用(marketplace / episodic 引用應保留)
