## ADDED Requirements

### Requirement: 退役的 settings.json hook 註冊由 modify_ 腳本主動移除
`home/dot_claude/modify_settings.json.sh.tmpl` 為 chezmoi `modify_` 腳本——它 **patch** 既有的 `settings.json`，而非重新 render 整份檔案。因此停止寫入某個欄位 SHALL NOT 被視為移除該欄位：已 apply 過的機器會原地保留舊值。退役一個由此腳本註冊的 hook 時，該腳本 SHALL 明確刪除既有註冊，而不僅是刪掉寫入它的那段 jq。

刪除 SHALL 為**外科式**——以 `map(select(... | not))` 只濾掉目標 hook 的條目，SHALL NOT 整體覆寫或 `del` 掉該 hook key，因為 plugin 與其他工具可能於 runtime 在同一個 key 下註冊條目。當外科式移除後陣列為空時，該 key SHALL 被 `del` 掉，以免留下空陣列。

hook script 本身的部署路徑另 SHALL 依「退役的 Claude command 由 .chezmoiremove 跨機器修剪」於 `home/.chezmoiremove` 點名；兩者缺一都會留下殘骸——只刪 script 會留下指向不存在檔案的註冊，只刪註冊會留下孤兒 script。

#### Scenario: 退役的 rtk PreToolUse 註冊被移除
- **WHEN** 機器的 `settings.json` 內含 command 為 `bash ~/.claude/hooks/rtk-rewrite.sh` 的 `PreToolUse` 條目且執行 chezmoi apply
- **THEN** 該條目被移除；`PreToolUse` 因此為空陣列時，`hooks.PreToolUse` key 一併被刪除

#### Scenario: 其他工具註冊的同 key 條目不受影響
- **WHEN** `settings.json` 的 `hooks.PreToolUse` 同時存在非 chezmoi 寫入的條目
- **THEN** 該條目 SHALL 保持不變，僅目標 hook 的條目被濾除

#### Scenario: 已清理的機器重跑不報錯
- **WHEN** `settings.json` 內已無該 hook 條目且再次執行 chezmoi apply
- **THEN** apply 正常完成，`settings.json` 內容不再變動（冪等）

#### Scenario: 新機器 bootstrap 不產生空殼
- **WHEN** 機器上尚無 `settings.json`，以空物件 `{}` 為起點執行 chezmoi apply
- **THEN** 產出的 `settings.json` SHALL NOT 含 `hooks.PreToolUse` key

### Requirement: 退役的 hook script 與其設定目錄一併修剪
`~/.claude/hooks/` 與工具自有的設定目錄（如 `~/.config/<tool>/`、Windows 的 `~/AppData/Roaming/<tool>/`）皆非 `exact_` 管理，刪除 source 不會移除已部署的 target。退役一個工具時，其 hook script、設定目錄、以 external 部署的 binary，以及該工具寫下的 runtime state SHALL 於 `home/.chezmoiremove` 中點名。

跨 OS 的路徑 SHALL 一律列出而不加 template 條件判斷：移除該 OS 上不存在的路徑為 no-op，條件判斷只增加閱讀成本。

#### Scenario: rtk 的部署檔案跨機器移除
- **WHEN** 機器上存在 `~/.claude/hooks/rtk-rewrite.sh`、`~/.config/rtk/`、`~/AppData/Roaming/rtk/` 或 `~/.local/bin/rtk[.exe]` 之任一且執行 chezmoi apply
- **THEN** 存在的路徑被移除

#### Scenario: 不存在的跨 OS 路徑不造成失敗
- **WHEN** 在 Linux 上 apply，而 `.chezmoiremove` 列有 `AppData/Roaming/rtk`
- **THEN** apply 正常完成，該條目為 no-op
