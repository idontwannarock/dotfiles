## Why

`superpowers` plugin(`claude-plugins-official`)自 dev-workflow rework 後已解除接線,其 workflow skills 全由自家 `~/.claude/skills/`(grill/tdd/diagnose/verify-done/worktree/finish-branch)取代。先前保留它的唯一理由是「怕 episodic-memory 基礎設施依賴它」。本次已驗證該依賴不存在:episodic-memory 來自 **不同 marketplace**(`superpowers-marketplace`)、自帶 `hooks/hooks.json`(SessionStart sync 用 plugin-relative 的 `${CLAUDE_PLUGIN_ROOT}`)、對 conversation-archive 路徑零引用;superpowers plugin 甚至沒有 hooks 目錄。保留它只是徒增 skill 命名空間污染與維護面。

## What Changes

- 從 `run_onchange_install-03-claude-config`(`.sh.tmpl` + `.ps1.tmpl` parity)移除 `claude plugin install superpowers`。
- 保留 `claude plugin marketplace add obra/superpowers-marketplace`(episodic-memory + elements-of-style 仍需)。
- 保留既有的 `rm -rf .../superpowers-marketplace/superpowers` cache cleanup(移除後更需要,避免 marketplace clone 帶入的 superpowers 陰影)。
- 刪除 `home/.chezmoitemplates/user-system-prompt.md` §8「Superpowers 過渡護欄」整節,並重編號後續章節。
- 更新 `docs/claude-code.md`:plugin 表移除 superpowers 列,並修訂 design-doc 歷史脈絡段落中「plugin 目前仍安裝但…移除待驗證」的措辭。
- 更新 `~/.claude/CLAUDE.md` §8(全域指令,由 dotfiles 外部管理,單獨處理)—— 移除過渡護欄段。
- 在本機執行 `claude plugin uninstall superpowers@claude-plugins-official` 並驗證 episodic-memory 仍可運作(專案 test-first 慣例)。

## Capabilities

### New Capabilities

（無)

### Modified Capabilities

- `claude-config`:「Claude plugin 安裝透過 run_onchange_ 腳本」requirement 的措辭由「安裝 superpowers marketplace 與 plugin」收斂為「安裝 superpowers marketplace 與所需 plugins(episodic-memory、elements-of-style 等),不含已退役的 superpowers plugin」。

## Impact

- `home/run_onchange_install-03-claude-config.sh.tmpl`、`.ps1.tmpl`
- `home/.chezmoitemplates/user-system-prompt.md`(§8 刪除 + 章節重編號)
- `docs/claude-code.md`(plugin 表 + 歷史脈絡段)
- 本機 runtime:`~/.claude/settings.json` 的 `enabledPlugins` 移除 `superpowers@claude-plugins-official`(由 `claude plugin uninstall` 處理,非 chezmoi 管理)
- 失去 `superpowers:*` skills(brainstorming/writing-plans/systematic-debugging 等)—— 已由自家 skills 取代,屬預期。
- 無破壞性影響於 episodic-memory / elements-of-style / marketplace。
