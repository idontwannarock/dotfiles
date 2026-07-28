## Why

`2026-07-22-remove-superpowers-plugin` 停止了 superpowers plugin 的安裝,但其 design 明確決定「本機 uninstall 走 runtime,chezmoi 不管這塊」— 移除只發生在執行者當下那台機器,不會隨 `chezmoi apply` 傳播。結果:本機今日稽核時 `superpowers@claude-plugins-official` v6.2.0 仍在(`installedAt` 停留在 2026-05-17,未經 uninstall/reinstall 循環),且被 Claude Code 每次啟動自動更新。

同一支腳本的 cache 清理只涵蓋 `superpowers-marketplace/superpowers`(防禦性,實測為 no-op),未涵蓋 plugin 實際殘留的 `claude-plugins-official/superpowers`(4.2 MB)。

## What Changes

- `run_onchange_install-03-claude-config.sh.tmpl` 與 `.ps1.tmpl` 加入冪等的 `claude plugin uninstall superpowers@claude-plugins-official`,僅在偵測到已安裝時執行
- 兩版腳本**增補** `claude-plugins-official/superpowers` 的 cache 清理;既有的 `superpowers-marketplace/superpowers` 清理原樣保留(其防禦意圖見 archived design)
- `.chezmoiremove` 加入 `.claude/commands/opsx/workflow.md` — 已被 `dev-workflow` skill 取代的孤兒 command,內文仍引用 10 處 `superpowers:*` skill
- **不變**:`obra/superpowers-marketplace` 的 marketplace 註冊保留,episodic-memory 與 elements-of-style 由它供應

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `claude-config`: plugin 安裝要求由「不安裝 superpowers」的被動描述,改為「主動 uninstall 並清除其 cache」的可驗證要求(補完 `2026-07-22-remove-superpowers-plugin` 留下的跨機器收斂缺口);並新增退役 command 由 `.chezmoiremove` 跨機器修剪的要求

## Impact

- `home/run_onchange_install-03-claude-config.sh.tmpl`(Unix/macOS/WSL)
- `home/run_onchange_install-03-claude-config.ps1.tmpl`(Windows)
- `home/.chezmoiremove`
- `openspec/specs/claude-config/spec.md`

風險面:兩支腳本為 `run_onchange_`,內容變更即在所有機器重跑。uninstall 必須冪等且在 plugin 不存在時靜默通過,否則 `set -euo pipefail` 會讓後續的 jdtls / MCP / episodic-memory 修復步驟全數中斷。
