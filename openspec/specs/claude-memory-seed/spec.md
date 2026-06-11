# claude-memory-seed Specification

## Purpose
TBD - created by archiving change add-auto-memory-seed. Update Purpose after archive.
## Requirements
### Requirement: bare+worktree 偵測與 autoMemoryDirectory 目標推導

`claude-memory-seed` SHALL 以 git common-dir 判定佈局:當 `basename(realpath(git rev-parse --git-common-dir))` 為 `.bare` 時視為 bare+worktree,否則(含一般 repo 的 `.git`、或非 git repo)視為不適用。bare+worktree 時,目標 `autoMemoryDirectory` 值 SHALL 為 `~/.claude/memory/<repo-name>`,其中 `<repo-name>` = `basename(dirname(realpath(git-common-dir)))`,使同一 repo 的所有 worktree 解析到同一值。

#### Scenario: bare+worktree worktree 推導出容器名

- **WHEN** cwd 為 `<container>/.bare` 佈局下任一 worktree,執行 `claude-memory-seed where`
- **THEN** 印出 `~/.claude/memory/<container>`(以容器 basename 為 `<repo-name>`)

#### Scenario: 一般 repo 不適用

- **WHEN** cwd 為 common-dir 為 `.git` 的一般 repo
- **THEN** helper 判定不適用並安靜 exit 0,不寫入任何設定

#### Scenario: container 根目錄不適用

- **WHEN** cwd 為只含 `.bare/` 的容器根目錄(本身非 worktree,git 無 common-dir)
- **THEN** helper 安靜 exit 0,不寫入任何設定

### Requirement: apply 只在缺值時寫入且不覆寫既有設定

`claude-memory-seed apply` SHALL 僅在目標 worktree 的 `.claude/settings.local.json` **缺少**(不存在或為空)`autoMemoryDirectory` 時寫入推導值;已存在非空值時 SHALL NOT 覆寫之。寫入 SHALL 以 JSON 合併方式保留檔內既有其他 key,並以 LF 結尾。`jq` 不可用時 SHALL 安靜 no-op 而不阻斷呼叫端。

#### Scenario: 缺值時種入

- **WHEN** 在 bare+worktree worktree 內,其 `.claude/settings.local.json` 無 `autoMemoryDirectory`
- **THEN** `apply` 寫入 `autoMemoryDirectory = ~/.claude/memory/<repo-name>`,且保留檔內既有 keys(如 `permissions`)

#### Scenario: 已設值不覆寫

- **WHEN** worktree 的 `.claude/settings.local.json` 已有非空 `autoMemoryDirectory`
- **THEN** `apply` 保留原值不動,exit 0

#### Scenario: 重複執行 idempotent

- **WHEN** 對同一 worktree 連續執行 `apply` 兩次
- **THEN** 第二次偵測到已設值,不再寫入(無重複/抖動的 diff)

#### Scenario: 無 jq 安靜略過

- **WHEN** 執行環境無 `jq`
- **THEN** `apply` 不寫入且不報錯阻斷(exit 0)

### Requirement: SessionStart 觸發以 union-append 併入且不覆寫既有 hook

機器的 Claude `settings.json` SHALL 含一個 SessionStart hook 呼叫 `claude-memory-seed apply`,使每次 session 啟動都嘗試種子。該 hook SHALL 由 `modify_settings` 以 **union-append** 併入:既有 SessionStart entries(如其他工具於 runtime 註冊者)SHALL 被保留;當既有任一 SessionStart hook command 已含 `claude-memory-seed` 時 SHALL NOT 重複加入。

#### Scenario: 保留既有 SessionStart entries

- **WHEN** 現行 settings.json 的 SessionStart 已含其他工具註冊的 entry,經 `modify_settings` 處理
- **THEN** 那些 entry 仍在,且新增一個呼叫 `claude-memory-seed apply` 的 entry

#### Scenario: 重複套用不重加

- **WHEN** settings.json 的 SessionStart 已含 `claude-memory-seed` 的 hook,再次經 `modify_settings` 處理
- **THEN** 不再新增重複 entry

### Requirement: post-checkout 觸發沿用全域 dispatcher 且不覆蓋 repo-local hook

全域 `post-checkout` dispatcher SHALL 在其既有步驟(`localfiles restore`)之後呼叫 `claude-memory-seed apply`,且呼叫失敗 SHALL NOT 阻斷 checkout。dispatcher 對 repo-local `.githooks/post-checkout` 與 `.git/hooks/post-checkout` 的 chain(含 realpath 防遞迴)SHALL 維持不變。

#### Scenario: checkout 後種子

- **WHEN** 對 bare+worktree repo 執行 `git worktree add` 或 branch checkout,且該 worktree 尚無 `autoMemoryDirectory`
- **THEN** dispatcher 觸發 `claude-memory-seed apply`,種入推導值

#### Scenario: 保留 repo-local hook

- **WHEN** repo 內存在可執行的 `.githooks/post-checkout`
- **THEN** dispatcher 在種子步驟後仍呼叫該 repo-local hook(傳入原始參數),不因新增步驟而被覆蓋

