## REMOVED Requirements

### Requirement: bare+worktree 偵測與 autoMemoryDirectory 目標推導

(由「git repo 偵測與 path-slug 目標推導」取代:適用範圍從 bare-only 擴大到所有 git repo,key 從 folder basename 改為正規路徑 slug。)

### Requirement: apply 只在缺值時寫入且不覆寫既有設定

(由「apply:自動遷移既有記憶並依覆寫政策寫入」取代:新增 path-based 自動遷移,覆寫政策從「一律不覆寫」放寬為「受管根值可升級」。)

## ADDED Requirements

### Requirement: git repo 偵測與 path-slug 目標推導

`claude-memory-seed` SHALL 對**任何具 toplevel 的 git repo**生效(非 git cwd 視為不適用,
安靜 exit 0)。目標 `autoMemoryDirectory` 值 SHALL 為 `~/.claude/memory/<id>`,其中
`<id> = slug(dirname(realpath(git rev-parse --git-common-dir)))`,slug 為把絕對路徑的 `/`
換成 `-`。因 `dirname(common-dir)` 對一般 repo 為主 checkout 路徑、對 bare+worktree 為容器
路徑,故同一 repo 的所有 worktree SHALL 解析到同一 `<id>`,且不同路徑的 repo SHALL 解析到
不同 `<id>`(完整路徑唯一,不撞桶)。

#### Scenario: 一般 repo 主 checkout 推導路徑 slug

- **WHEN** cwd 為一般 repo(common-dir 為 `<repo>/.git`),執行 `claude-memory-seed where`
- **THEN** 印出 `~/.claude/memory/<slug(<repo> 絕對路徑)>`

#### Scenario: 同 repo 的 worktree 解析到同一 id

- **WHEN** 在同一 repo 的主 checkout 與其 linked worktree 各執行 `claude-memory-seed where`
- **THEN** 兩者印出的目標路徑相同(皆以主 checkout 路徑 slug 為 `<id>`)

#### Scenario: bare+worktree 以容器路徑為 id

- **WHEN** cwd 為 `<container>/.bare` 佈局下任一 worktree
- **THEN** `<id>` 為 `<container>` 絕對路徑的 slug

#### Scenario: 非 git cwd 不適用

- **WHEN** cwd 不在任何 git repo 內
- **THEN** helper 安靜 exit 0,不寫入任何設定

### Requirement: apply:自動遷移既有記憶並依覆寫政策寫入

`claude-memory-seed apply` SHALL 在目標 `~/.claude/memory/<id>/` **不存在或為空**時,依序尋找
既有記憶來源並將其 `memory/` 內容 `mv` 進目標(第一個命中即止):① 舊 basename 方案
`~/.claude/memory/<basename(canonical)>/`;② Claude 預設 `~/.claude/projects/<id>/memory/`。
遷移 SHALL 只搬 `memory/`,不動同層 transcripts。當目標**已有內容**時 SHALL NOT 搬移或覆蓋,
僅印警告。`jq` 不可用時 SHALL 安靜 no-op。

寫入 `autoMemoryDirectory` 的覆寫政策:現值**缺**、或現值開頭為受管根(`~/.claude/memory/`
或 `~/.claude/projects/`)→ SHALL 寫入 canonical 目標(含把舊 basename 值升級為 path-slug);
現值指向受管根**以外**(使用者刻意自訂)→ SHALL NOT 覆寫。寫入 SHALL 保留檔內其他 key 並以
LF 結尾。

#### Scenario: 從 Claude 預設位置遷移

- **WHEN** 一般 repo 首次 apply,`~/.claude/memory/<id>/` 不存在但 `~/.claude/projects/<id>/memory/` 有內容
- **THEN** 該 `memory/` 內容被搬到 `~/.claude/memory/<id>/`,transcripts 留在 `projects/<id>/`

#### Scenario: 升級舊 basename 目錄

- **WHEN** 既有 `~/.claude/memory/<basename(canonical)>/` 存在而 path-slug 目標尚不存在
- **THEN** apply 將其 rename 為 `~/.claude/memory/<id>/`,並把 settings 的舊 basename 值升級為 path-slug

#### Scenario: 目標已有內容則不覆蓋

- **WHEN** `~/.claude/memory/<id>/` 已有內容
- **THEN** apply 不搬移、不覆蓋,僅確保 settings 指向它

#### Scenario: 尊重受管根以外的自訂值

- **WHEN** settings 的 `autoMemoryDirectory` 指向 `~/.claude/memory` 與 `~/.claude/projects` 以外的路徑
- **THEN** apply 保留該值不動

#### Scenario: 重複執行 idempotent

- **WHEN** 對同一 repo 連續執行 apply 兩次
- **THEN** 第二次目標已有內容、值已為 canonical → 不搬移、不產生變更

## MODIFIED Requirements

### Requirement: post-checkout 觸發沿用全域 dispatcher 且不覆蓋 repo-local hook

全域 `post-checkout` dispatcher SHALL 在其既有步驟(`localfiles restore`)之後呼叫
`claude-memory-seed apply`,且呼叫失敗 SHALL NOT 阻斷 checkout。dispatcher 對 repo-local
`.githooks/post-checkout` 與 `.git/hooks/post-checkout` 的 chain(含 realpath 防遞迴)SHALL
維持不變。

#### Scenario: checkout 後種子

- **WHEN** 對任一 git repo 執行 `git worktree add` 或 branch checkout,且其目標 `~/.claude/memory/<id>` 尚未建立
- **THEN** dispatcher 觸發 `claude-memory-seed apply`,完成遷移/種入

#### Scenario: 保留 repo-local hook

- **WHEN** repo 內存在可執行的 `.githooks/post-checkout`
- **THEN** dispatcher 在種子步驟後仍呼叫該 repo-local hook(傳入原始參數),不因新增步驟而被覆蓋
