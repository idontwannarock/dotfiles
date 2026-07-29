## Why

`openspec/specs/claude-config/spec.md` 同時載有兩條互相對撞的 requirement:

- 「Claude Code 設定透過 chezmoi exact_ 目錄部署」(第 8-21 行)—— 宣稱 `~/.claude/` 下的 commands SHALL 由 `exact_` 管理,repo 中移除的檔案 apply 後自動清除。
- 「退役的 Claude command 由 .chezmoiremove 跨機器修剪」(第 99 行起)—— 明文指出 `~/.claude/commands/` **為非 `exact_` 目錄**,不會自動修剪,退役項須於 `home/.chezmoiremove` 點名。

實作與後者一致:`home/dot_claude/` 底下只有 `exact_agents/` 有前綴,`commands/`、`skills/`、`hooks/` 皆無;`home/.chezmoiremove` 已存在且在用。因此前者是過期敘述,其 Scenario「移除 command 後自動清除」在現實中不會通過。

這不是要在兩條路線間做選擇 —— 選擇早已由實作與第二條 requirement 做出。問題是矛盾的舊敘述還留著,讓 spec 無法作為權威來源:讀者依第 8-21 行行事,會以為刪掉 source 檔就等於從所有機器移除,而實際上機器會靜默保留。這正是退役 superpowers plugin 時踩過兩次的同一類坑(PR #31、#38)。

`exact_` 之所以不適用於這些目錄,理由是結構性的:`~/.claude/commands/` 與 `~/.claude/skills/` 天生會有非 chezmoi 管理的檔案 —— 機器專屬的、實驗中的、或其他工具放進去的。本機實測即有 3 個(`commands/git/amend.md`、`push.md`、`undo.md`)。`exact_` 的前提是「這個目錄完全屬於 chezmoi」,在此不成立,套用它會靜默刪除這些檔案。

## What Changes

- **移除** `claude-config` 中「Claude Code 設定透過 chezmoi exact_ 目錄部署」requirement 的過期部分:不再宣稱 commands 由 `exact_` 管理。`exact_agents/` 確實走 `exact_`,該部分保留。
- **擴充**「退役項由 .chezmoiremove 跨機器修剪」requirement,使其涵蓋 `~/.claude/skills/`(與 commands 同屬非 `exact_` 目錄、同一套推理),並明確記載「為何這些目錄不用 `exact_`」的判準,避免未來有人再度把它們改成 `exact_`。
- 修正 `README.md` 與 `docs/claude-code.md` 中沿用舊說法的目錄樹註解。

非目標:不改變任何實際部署行為。本 change 只讓 spec 與文件追上早已存在的實作,不動 `home/dot_claude/` 的任何前綴。

## Capabilities

### New Capabilities

無。

### Modified Capabilities
- `claude-config`: 移除 commands 走 `exact_` 的過期要求;擴充 `.chezmoiremove` 修剪要求至 skills,並載明「目錄含非 chezmoi 管理檔案時不得使用 `exact_`」的判準。

## Impact

修改檔案:
- `openspec/specs/claude-config/spec.md`(經 delta + sync)
- `README.md`(第 325 行目錄樹註解)
- `docs/claude-code.md`(第 13 行目錄樹註解)

無行為變更、無遷移需求。`home/dot_claude/` 下的檔案與前綴一律不動,因此 `chezmoi apply` 的產出在此 change 前後完全相同。
