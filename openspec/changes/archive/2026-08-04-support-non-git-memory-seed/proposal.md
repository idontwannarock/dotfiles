## Why

`claude-memory-seed` 目前明文只對 git repo 生效(spec:「非 git cwd 視為不適用」),但機器上有
一批**非 git 的工作目錄**照樣天天開 session。它們的 auto-memory 至今仍留在 Claude 私有的
`~/.claude/projects/<id>/memory/`,沒有落到共享的 `~/.claude/memory/<id>`——與「memory 放在
可預期的共享路徑、達成 model agnostic」的目標直接相牴觸。

實測受影響的有 4 個目錄、共 40 個記憶檔:

| 目錄 | 記憶檔數 |
|------|---------|
| `/home/howardwang/devops/livekit` | 30 |
| `/home/howardwang/ws/lab/hr-chatbot` | 7 |
| `/home/howardwang/devops/monitor` | 2 |
| `/home/howardwang/devops/opensearch` | 1 |

順帶確認了一件事:觸發面**沒有**缺口。`SessionStart` hook 每次開 session 都會呼叫 seeder,
不管是不是 git;真正擋下來的是 seeder 自己的 `[ -n "$toplevel" ] || return 0`。所以這是改
需求,不是補 hook。

同時,上一輪 `unify-memory-path-slug` 的 proposal 留過一條 known edge:「若路徑含 Claude 另行
編碼的字元,遷移來源比對可能 miss」。這次實測把它從假設變成確證——Claude 的 slug 額外把 `_`
轉成 `-`,而我們只轉 `/`:

```
/home/howardwang/ws/hktv/tw/cashback/cashback_api
  Claude:  ~/.claude/projects/-home-howardwang-ws-hktv-tw-cashback-cashback-api/
  我們:    ~/.claude/memory/  -home-howardwang-ws-hktv-tw-cashback-cashback_api/
```

含 `_` 的 4 個 repo(cashback_api、chat_setting_api、mms_chat_api、mms_store_api)遷移來源
永遠找不到。目前那些 `projects/*/memory` 剛好都是空的,尚未實際掉記憶,但缺口是真的。既然要
動這支 script,一併收掉。

## What Changes

- **解除 non-git gate**:seeder 的 anchor 從「必須有 git toplevel」放寬為
  `canonical_root()` 失敗時 fallback 到 `${CLAUDE_PROJECT_DIR:-$PWD}`。git repo 走原路
  (worktree 收斂行為完全不變),非 git 目錄以專案根本身為 anchor。
  `<id>` 的推導規則**不變**,仍是自家的 `slug(path) = tr '/' '-'`——`CLAUDE_PROJECT_DIR`
  是路徑不是 slug,採用它不改變任何既有 memory 目錄命名。

- **新增寫入護欄**:cwd 解析為 `$HOME`、`/`、或位於 `/tmp/` 之下時 SHALL NOT 寫入。
  - `$HOME` 是必要護欄而非防禦性冗餘:此時 settings 路徑會落在
    `~/.claude/settings.local.json`,那是 Claude 的 **user-level** 設定檔,寫進去會把
    `autoMemoryDirectory` 全域綁死到單一目錄,所有專案記憶混在一起。
  - `/tmp/` 擋掉 scratchpad 污染(`projects/` 已有 2 個 scratchpad 桶)。

- **修遷移來源查找(既有 bug)**:不再用 `$id` 直接拼 `~/.claude/projects/$id/memory`,改為
  掃 `~/.claude/projects/*`,把兩邊名稱的 `[-_.]` 一律正規化成 `-` 後比對。不去猜 Claude
  的完整編碼規則(`.` 如何處理無樣本可驗),規則無關,未來新增轉換字元也一併涵蓋。

- **既有 4 個目錄採懶遷移**:改動 ship 後,下次在該目錄開 session 由 `SessionStart` hook
  自行搬移。**不寫 `backfill` 子命令**——slug 不可逆(`-a-b-c` 無法還原 `b/c` 或 `b-c`),
  為 4 個目錄寫路徑試探邏輯不划算,且懶遷移期間記憶不會遺失,只是延後移動。

- **補測試**:目前 `tests/` 只有 PowerShell 測試,這支 sh script 完全沒有測試覆蓋。本次為
  新增的 anchor fallback、三道護欄、正規化比對補上測試。

## Capabilities

### Modified Capabilities

- `claude-memory-seed`: 適用範圍從「僅 git repo」擴大到「git repo + 非 git 專案目錄」;
  新增 `$HOME` / `/` / `/tmp` 三道寫入護欄;遷移來源查找從字串拼接改為正規化比對。

## Impact

- **修改檔案**:
  - `home/dot_local/bin/executable_claude-memory-seed` —— anchor fallback、護欄、遷移來源查找。
  - `openspec/specs/claude-memory-seed/spec.md` —— 由 delta spec 驅動更新(非 git 不適用 → 適用且加護欄)。
  - `home/dot_agent/reference/bare-worktree/claude-state.md` —— 補一句非 git 目錄的適用說明。
  - `tests/` —— 新增本 script 的測試。
- **不變**:`executable_post-checkout`(git-only,呼叫不變)、`modify_settings.json.sh.tmpl`
  的 SessionStart entry(呼叫不變)、既有 18 個 `~/.claude/memory/<id>` 目錄命名(一字不改)。
- **blast radius**:此後在**任何**非 git 目錄開 session 都會生出 `.claude/settings.local.json`
  與對應的 `~/.claude/memory/<id>/`。護欄擋掉 `$HOME`、`/`、`/tmp`;其餘目錄視為使用者
  刻意在那裡工作,予以種子。既有 `settings.local.json` 的其他 key 由 jq merge 保留。
- **已知邊角**:非 git 目錄沒有 worktree 收斂概念,從子目錄開 session 會分到不同 `<id>`
  ——這與 Claude 自身 `projects/` 的分桶行為一致,不視為退步。
