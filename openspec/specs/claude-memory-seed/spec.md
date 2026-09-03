# claude-memory-seed Specification

## Purpose
把 Claude Code 的 auto-memory 統一到 `~/.agent/memory/<id>` 這個可預期的共享
路徑,使記憶不再鎖在 Claude 私有的 `projects/` 樹下(model agnostic),且同一 repo 的
所有 worktree 共用一份記憶。適用於 git repo 與非 git 專案目錄。

## Requirements
### Requirement: SessionStart 觸發以 union-append 併入且不覆寫既有 hook

機器的 Claude `settings.json` SHALL 含一個 SessionStart hook 呼叫 `claude-memory-seed apply`,使每次 session 啟動都嘗試種子。該 hook SHALL 由 `modify_settings` 以 **union-append** 併入:既有 SessionStart entries(如其他工具於 runtime 註冊者)SHALL 被保留;當既有任一 SessionStart hook command 已含 `claude-memory-seed` 時 SHALL NOT 重複加入。

#### Scenario: 保留既有 SessionStart entries

- **WHEN** 現行 settings.json 的 SessionStart 已含其他工具註冊的 entry,經 `modify_settings` 處理
- **THEN** 那些 entry 仍在,且新增一個呼叫 `claude-memory-seed apply` 的 entry

#### Scenario: 重複套用不重加

- **WHEN** settings.json 的 SessionStart 已含 `claude-memory-seed` 的 hook,再次經 `modify_settings` 處理
- **THEN** 不再新增重複 entry

### Requirement: post-checkout 觸發沿用全域 dispatcher 且不覆蓋 repo-local hook

全域 `post-checkout` dispatcher SHALL 在其既有步驟(`localfiles restore`)之後呼叫
`claude-memory-seed apply`,且呼叫失敗 SHALL NOT 阻斷 checkout。dispatcher 對 repo-local
`.githooks/post-checkout` 與 `.git/hooks/post-checkout` 的 chain(含 realpath 防遞迴)SHALL
維持不變。

#### Scenario: checkout 後種子

- **WHEN** 對任一 git repo 執行 `git worktree add` 或 branch checkout,且其目標 `~/.agent/memory/<id>` 尚未建立
- **THEN** dispatcher 觸發 `claude-memory-seed apply`,完成遷移/種入

#### Scenario: 保留 repo-local hook

- **WHEN** repo 內存在可執行的 `.githooks/post-checkout`
- **THEN** dispatcher 在種子步驟後仍呼叫該 repo-local hook(傳入原始參數),不因新增步驟而被覆蓋

### Requirement: git repo 偵測與 path-slug 目標推導

`claude-memory-seed` SHALL 對**任何具 toplevel 的 git repo,以及任何非 git 的專案目錄**生效。

推導 SHALL 明確區分兩個獨立概念:

| 概念 | git repo | 非 git |
|------|---------|--------|
| **id 錨點** `id_root` | `dirname(realpath(git rev-parse --git-common-dir))` | `CLAUDE_PROJECT_DIR`,未設時為 cwd |
| **設定落點** `settings_root` | `git rev-parse --show-toplevel` | `CLAUDE_PROJECT_DIR`,未設時為 cwd |

兩者 SHALL 以 `cd -P` 正規化為 physical path,使 symlink 過來的專案目錄與其實體路徑解析到
同一 `<id>`。

目標 `autoMemoryDirectory` 值 SHALL 為 `~/.agent/memory/<id>`,其中
`<id> = slug(id_root)`,slug 為把絕對路徑的 `/` 換成 `-`。slug 規則 SHALL NOT 因本需求而
改變。

因 git repo 的 `id_root` 為 `dirname(common-dir)`(一般 repo 是主 checkout、bare+worktree
是容器),同一 repo 的所有 worktree SHALL 解析到同一 `<id>`;而 `settings_root` 為各
worktree 自身的 toplevel,故每個 worktree SHALL 各自持有指向同一 `<id>` 的
`settings.local.json`。不同路徑的專案 SHALL 解析到不同 `<id>`。

#### Scenario: 一般 repo 主 checkout 推導路徑 slug

- **WHEN** cwd 為一般 repo(common-dir 為 `<repo>/.git`),執行 `claude-memory-seed where`
- **THEN** 印出 `~/.agent/memory/<slug(<repo> 絕對路徑)>`

#### Scenario: 同 repo 的 worktree 解析到同一 id

- **WHEN** 在同一 repo 的主 checkout 與其 linked worktree 各執行 `claude-memory-seed where`
- **THEN** 兩者印出的目標路徑相同(皆以主 checkout 路徑 slug 為 `<id>`)

#### Scenario: worktree 的設定寫在自己的 toplevel

- **WHEN** 於 linked worktree 執行 apply
- **THEN** 寫入的是**該 worktree** 的 `.claude/settings.local.json`(非主 checkout 的),
  其 `autoMemoryDirectory` 值為共享的 `~/.agent/memory/<id>`

#### Scenario: bare+worktree 以容器路徑為 id

- **WHEN** cwd 為 `<container>/.bare` 佈局下任一 worktree
- **THEN** `<id>` 為 `<container>` 絕對路徑的 slug

#### Scenario: 非 git 專案目錄以自身為錨點

- **WHEN** cwd 為非 git 的專案目錄(如 `/home/u/devops/livekit`),執行 apply
- **THEN** `<id>` 為該目錄絕對路徑的 slug,且 `.claude/settings.local.json` 寫在該目錄下

#### Scenario: 非 git 時優先採用 CLAUDE_PROJECT_DIR

- **WHEN** 於非 git 目錄的**子目錄**執行 apply,且 `CLAUDE_PROJECT_DIR` 指向專案根
- **THEN** `<id>` 依 `CLAUDE_PROJECT_DIR` 推導,而非依 cwd

#### Scenario: CLAUDE_PROJECT_DIR 未設時 fallback 到 cwd

- **WHEN** 於非 git 目錄執行 apply 且 `CLAUDE_PROJECT_DIR` 未設定
- **THEN** 以 cwd 為錨點,不因缺少該變數而失敗或 no-op

#### Scenario: symlink 專案目錄正規化到實體路徑

- **WHEN** 經由 symlink 進入某非 git 專案目錄執行 apply
- **THEN** `<id>` 依 physical path 推導,與直接進入實體路徑執行的結果相同

### Requirement: 寫入護欄:三種不得落地的設定位置

`claude-memory-seed apply` SHALL 在解析出 `settings_root` 後、寫入任何檔案**之前**檢查護欄。
當 `settings_root` 符合下列任一條件時 SHALL 安靜 exit 0,SHALL NOT 建立 `.claude/` 目錄、
SHALL NOT 寫入 `settings.local.json`、SHALL NOT 執行遷移:

1. `settings_root` 等於 `$HOME`
2. `settings_root` 等於 `/`
3. `settings_root` 位於 `/tmp/` 之下(含 `/tmp` 本身)

比對 SHALL 為 **resolved-to-resolved**:`settings_root` 是 `pwd -P` 的產物,故 `$HOME` 與
`/tmp` 兩個基準值 SHALL 同樣先解析為 physical path 再比對。單邊解析會使護欄在任一側含
symlink 或尾斜線時永遠不相等而靜默失效;此舉亦使 macOS 的 `/tmp` → `/private/tmp` 自動涵蓋,
無需硬編平台特例。基準值解析失敗時 SHALL 退回原字串,使護欄的失敗方向為「多擋」而非「少擋」。

護欄 SHALL 統一套用,**不區分**該位置是否為 git repo。前綴相同但不在受擋目錄之下的路徑
(如 `/tmpfoo`、`$HOME` 的子目錄)SHALL NOT 被擋。

條件 1 是資料安全需求:該情境下設定路徑會是 `~/.claude/settings.local.json`,即 Claude 的
**user-level** 設定檔;寫入 `autoMemoryDirectory` 會使**所有**未自訂該值的專案共用同一個記憶
目錄。條件 3 阻止拋棄式 checkout 與 scratchpad 在 `~/.agent/memory/` 留下永久孤兒目錄
(`/tmp` 清空後該目錄指向不存在的路徑,永不再被讀取)。

#### Scenario: cwd 為 $HOME 時拒絕寫入

- **WHEN** 於 `$HOME` 執行 `claude-memory-seed apply`
- **THEN** exit 0,且 `~/.claude/settings.local.json` 未被建立或修改

#### Scenario: 經由 symlink 抵達的 $HOME 同樣拒絕

- **WHEN** `$HOME` 指向一個 symlink,於該路徑執行 apply
- **THEN** exit 0,且 symlink 指向的實體目錄下未產生 `.claude/settings.local.json`

#### Scenario: $HOME 本身是 git repo 時同樣拒絕

- **WHEN** `$HOME` 為一個 git repo 的 toplevel(如 yadm/homeshick 佈局),於其中執行 apply
- **THEN** exit 0,且 `~/.claude/settings.local.json` 未被建立或修改

#### Scenario: /tmp 之下拒絕寫入

- **WHEN** 於 `/tmp/<any>` 執行 apply(不論該目錄是否為 git repo)
- **THEN** exit 0,且該目錄下未產生 `.claude/settings.local.json`

#### Scenario: 根目錄拒絕寫入

- **WHEN** 於 `/` 執行 apply
- **THEN** exit code 為 0 且 stderr 無錯誤訊息(不可僅斷言檔案不存在——非特權使用者本就
  無法寫入 `/`,該斷言在護欄被移除時仍會通過)

#### Scenario: 前綴相同但不受擋的路徑仍被種子

- **WHEN** 於 `/tmpfoo`(與 `/tmp` 前綴相同但非其子路徑)執行 apply
- **THEN** 正常寫入 `.claude/settings.local.json`

### Requirement: apply 在任何情況下 SHALL exit 0

`claude-memory-seed apply` SHALL 以 exit code 0 結束,無論寫入是否成功。寫入失敗
(目標唯讀、磁碟已滿、權限不足、`jq` 缺席或失敗)SHALL 以 stderr 訊息呈現,SHALL NOT 反映在
退出碼上。

此不變量 SHALL 由 script 自身保證,而非依賴呼叫端包裝:呼叫端有兩處(Claude `SessionStart`
hook 與全域 `post-checkout` dispatcher),其中 `SessionStart` 的 hook command 是裸呼叫,
非零退出會使 session 啟動報錯。

#### Scenario: 寫入目標唯讀時仍 exit 0

- **WHEN** 於一個不可寫的專案目錄執行 apply
- **THEN** exit code 為 0,且失敗原因出現在 stderr

#### Scenario: 護欄拒絕時 exit 0

- **WHEN** 於任一受護欄拒絕的位置執行 apply
- **THEN** exit code 為 0

### Requirement: 寫入 settings 為原子操作,失敗 SHALL NOT 損毀既有檔案

寫入 `settings.local.json` SHALL 先產生同目錄的暫存檔,確認其**存在且非空**後才 rename 覆蓋
目標。`jq` 解析失敗、磁碟寫入失敗等情況 SHALL 使目標檔案保持原內容不變。

SHALL NOT 使用「直接重導向到目標檔」的寫法:重導向會在 `jq` 執行前就截斷目標,而
`printf | jq | tr` 這條 pipeline 的退出碼取自 `tr`,`jq` 的失敗不會反映在其中,因此單看退出碼
無法偵測——必須額外檢查產物非空。

#### Scenario: 既有 settings 格式損毀時不被清空

- **WHEN** 目標 `.claude/settings.local.json` 內容不是合法 JSON,執行 apply
- **THEN** 該檔案內容保持原樣(位元組數不變),且 exit 0

#### Scenario: 正常寫入後不留下暫存檔

- **WHEN** 於一般專案執行 apply 並成功寫入
- **THEN** 目標目錄下不存在暫存檔殘骸

### Requirement: apply:自動遷移既有記憶並依覆寫政策寫入

`claude-memory-seed apply` SHALL 在目標 `~/.agent/memory/<id>/` **不存在或為空**時,依序尋找
既有記憶來源並將其 `memory/` 內容 `mv` 進目標(第一個命中即止):

1. 已退役的根 `~/.claude/memory/<id>/`;
2. 該退役根下更舊的 basename 方案 `~/.claude/memory/<basename(id_root)>/`;
3. Claude 預設的 `~/.claude/projects/<claude-id>/memory/`。

來源 ③ SHALL NOT 以字串拼接 `<id>` 求得路徑,因為 Claude 的 slug 編碼與本工具不同(實測
Claude 額外把 `_` 轉為 `-`,如 `cashback_api` → `cashback-api`)。改為 SHALL 掃描
`~/.claude/projects/*/`,將候選目錄 basename 與 `<id>` 兩邊的 `[-_.]` 一律正規化為 `-` 後
比對,取第一個 `memory/` 非空的命中者,並將實際採用的來源印至 stderr。
`~/.claude/projects/` 不存在時 SHALL 安靜略過該來源。

遷移 SHALL 只搬 `memory/`,不動同層 transcripts。當目標**已有內容**時 SHALL NOT 搬移或覆蓋,
僅印警告。`jq` 不可用時 SHALL 安靜 no-op。

寫入 `autoMemoryDirectory` 的覆寫政策:現值**缺**、或現值開頭為受管根(`~/.agent/memory/`、
`~/.claude/memory/` 或 `~/.claude/projects/`)→ SHALL 寫入 canonical 目標(含把舊 basename 值
升級為 path-slug,以及把退役根 `~/.claude/memory/` 的值升級為 `~/.agent/memory/`);
現值指向受管根**以外**(使用者刻意自訂)→ SHALL NOT 覆寫。寫入 SHALL 保留檔內其他 key 並以
LF 結尾。

#### Scenario: 從 Claude 預設位置遷移

- **WHEN** 首次 apply,`~/.agent/memory/<id>/` 不存在但對應的 `~/.claude/projects/<claude-id>/memory/` 有內容
- **THEN** 該 `memory/` 內容被搬到 `~/.agent/memory/<id>/`,transcripts 留在 `projects/<claude-id>/`

#### Scenario: 從退役的 `~/.claude/memory/` 根遷移

- **WHEN** `~/.agent/memory/<id>/` 不存在或為空,而 `~/.claude/memory/<id>/` 有內容
- **THEN** apply 將其 rename 為 `~/.agent/memory/<id>/`,退役根下不留殘骸

#### Scenario: 升級退役根的 settings 值

- **WHEN** settings 的 `autoMemoryDirectory` 現值為 `~/.claude/memory/<id>`
- **THEN** apply 將其改寫為 `~/.agent/memory/<id>` —— 退役根列在受管根內正是為了讓尚未套用的機器能被推進

#### Scenario: 來源路徑含底線仍能命中

- **WHEN** 專案路徑為 `.../cashback_api`(我方 `<id>` 含 `_`),而 Claude 的桶名為
  `-...-cashback-api`(含 `-`),且該桶的 `memory/` 有內容
- **THEN** 正規化比對命中該桶並完成遷移

#### Scenario: projects 目錄不存在時不報錯

- **WHEN** `~/.claude/projects/` 不存在,執行 apply
- **THEN** 略過來源 ②,不因 glob 未展開而失敗,exit 0

#### Scenario: 升級舊 basename 目錄

- **WHEN** 既有 `~/.claude/memory/<basename(id_root)>/` 存在而 path-slug 目標尚不存在
- **THEN** apply 將其 rename 為 `~/.agent/memory/<id>/`,並把 settings 的舊 basename 值升級為 path-slug

#### Scenario: 目標已有內容則不覆蓋

- **WHEN** `~/.agent/memory/<id>/` 已有內容
- **THEN** apply 不搬移、不覆蓋,僅確保 settings 指向它

#### Scenario: 尊重受管根以外的自訂值

- **WHEN** settings 的 `autoMemoryDirectory` 指向 `~/.agent/memory`、`~/.claude/memory` 與 `~/.claude/projects` 以外的路徑
- **THEN** apply 保留該值不動

#### Scenario: 保留既有 settings 的其他 key

- **WHEN** 目標 `.claude/settings.local.json` 已含 `permissions.allow` 等其他 key
- **THEN** 寫入後那些 key 原封不動,僅新增/更新 `autoMemoryDirectory`

#### Scenario: 重複執行 idempotent

- **WHEN** 對同一專案連續執行 apply 兩次
- **THEN** 第二次目標已有內容、值已為 canonical → 不搬移、不產生變更
