## Why

`docs/claude-code.md` 原本列了 13 個 Claude Code plugin，實際安裝的只有 5 個。上一個 change（PR #37）把文件改成反映現況，但那只治了症狀：**那 10 個 plugin 若曾在其他機器上安裝過，仍然留在那些機器上**。

這正是 `superpowers` 退役時踩過的坑，spec 已把教訓寫下——當時「只把安裝那行刪掉」，於是已經 apply 過的機器繼續留著 plugin，而 `run_update-claude-plugins` 依 `enabledPlugins` 迭代，每次 apply 還在更新它。修法是讓腳本**主動 uninstall**，使移除隨 apply 傳播到每一台機器。

同樣的處理必須套用到這 10 個。從文件刪掉一列不會讓任何機器上的 plugin 消失。

## What Changes

- `run_onchange_install-03-claude-config` 的「退役 plugin」處理由**單一 `if` 區塊**改為**資料表驅動的迴圈**：`superpowers` 之外再納入 `claude-md-management`、`context7`、`code-simplifier`、`playwright`、`commit-commands`、`security-guidance`、`pr-review-toolkit`、`pyright-lsp`、`jdtls-lsp`、`claude-code-setup`，共 11 筆。
- Plugin cache 清理同樣改為資料表驅動，涵蓋每一筆退役項目。
- 兩個 interpreter（`.ps1` / `.sh`）皆比照調整，控制流一致。
- `chezmoi-author` skill 補上此慣例：**退役一個 plugin 等於把它加進退役表，而不是刪掉安裝那行**——與既有的「退役已部署檔案要用 `.chezmoiremove`」同一類約束。
- `docs/claude-code.md` 補上退役清單。

無 **BREAKING**。所有動作皆冪等，plugin 未安裝時為 no-op。

## Capabilities

### Modified Capabilities
- `claude-config`: 「主動移除已退役 plugin」的條文由 superpowers 單一特例推廣為資料表驅動的通則，涵蓋 11 個退役項目。

## Impact

| 類別 | 影響 |
|---|---|
| 腳本 | `home/run_onchange_install-03-claude-config.{ps1,sh}.tmpl` 各一段改寫 |
| skill | `home/.chezmoitemplates/skills/chezmoi-author.md` 新增一條退役慣例 |
| 文件 | `docs/claude-code.md` 補退役清單 |
| spec | `claude-config` 一支 delta |
| 使用者機器 | 下次 `chezmoi apply` 會 uninstall 這 10 個 plugin 並清其 cache |

**已確認不受影響**：`code-simplifier` 與 `code-reviewer` **agent** 來自 repo 的 `home/dot_claude/exact_agents/code-review/`，與同名的 `code-simplifier`、`pr-review-toolkit` plugin 無關，退役後仍可用。`code-review` plugin 為手動安裝且仍在使用，不列入退役表。
