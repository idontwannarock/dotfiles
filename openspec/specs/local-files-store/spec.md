# local-files-store Specification

## Purpose
TBD - created by archiving change 2026-06-11-add-local-files-store. Update Purpose after archive.
## Requirements
### Requirement: 全域 local-files store 佈局

被管理的 gitignored 本地檔 SHALL 以耐久副本保存於全域 store
`${XDG_STATE_HOME:-~/.local/state}/localfiles/<repo-id>/` 下,以 `_default/`
為共用桶,並以需要時才建立的 `<branch>/` 桶承載 per-branch override。
`<repo-id>` SHALL 推導為 `slug(dirname(realpath(git-common-dir)))`(把絕對路徑的
`/` 換成 `-`,與 claude-memory-seed 的 `<id>` 同式),使同一 repo 的所有 branch 與
worktree(含 bare+worktree 佈局)解析到同一桶,且不同路徑的 repo 不撞桶。

#### Scenario: 跨 worktree 解析到同一 repo-id

- **WHEN** 在同一 repo 的兩個不同 worktree 內各執行 `localfiles where`
- **THEN** 兩者印出的 store 路徑前綴(`.../localfiles/<repo-id>`)相同

#### Scenario: repo-id 為 canonical 路徑的 slug

- **WHEN** cwd 為一般 repo(common-dir `<repo>/.git`)或 bare+worktree(`<container>/.bare`)
- **THEN** `<repo-id>` 為主 checkout(`<repo>`)或容器(`<container>`)絕對路徑的 slug,而非個別 worktree 目錄名或 basename

### Requirement: localfiles restore 只填補缺檔(in-folder 為 source)

`localfiles restore` SHALL 僅在 worktree 預期路徑**缺少**某被管理檔時,才從
store 桶複製補齊;當 worktree 內已存在該檔,restore SHALL NOT 覆寫它。桶解析
SHALL 優先 `<branch>/`,不存在時 fallback `_default/`。

#### Scenario: 缺檔時自動補齊

- **WHEN** 新 worktree 內無 `.env`,且 store 的對應桶有 `.env`
- **THEN** `localfiles restore`(或 post-checkout 觸發之)將 `.env` 複製進 worktree 頂層

#### Scenario: 已存在則不覆寫

- **WHEN** worktree 內已有正在編輯的 `.env`
- **THEN** `localfiles restore` 保留該檔不動,不以 store 版本覆蓋

#### Scenario: branch 桶優先於 _default

- **WHEN** store 同時存在 `<branch>/.env` 與 `_default/.env`,且 cwd 在該 branch
- **THEN** restore 採用 `<branch>/.env`

### Requirement: localfiles backup 由使用者顯式推回(全域為備份)

`localfiles backup` SHALL 把 worktree 內現存的被管理檔複製回 store。預設寫入
`_default/` 桶;帶 `--branch` 時 SHALL 寫入當前 branch 的 `<branch>/` 桶並
建立之(使該 branch opt-in 為獨立 override)。

#### Scenario: 預設備份到 _default

- **WHEN** 在 worktree 內執行 `localfiles backup`
- **THEN** 現存的 `.env`/`.env.local`/`.env.*.local` 被複製到 `<repo-id>/_default/`

#### Scenario: --branch 建立並寫入 branch 桶

- **WHEN** 在 branch `feat-x` 內執行 `localfiles backup --branch`
- **THEN** 檔案被複製到 `<repo-id>/feat-x/`,且後續同 branch 的 restore 優先採用之

### Requirement: 全域 post-checkout dispatcher 多工而不靜默覆蓋

機器 SHALL 透過 `git config --global core.hooksPath` 指向 chezmoi 管理的全域
hooks 目錄,其 `post-checkout` SHALL 先執行 `localfiles restore`,再依序
chain repo-local `.githooks/post-checkout` 與 `.git/hooks/post-checkout`(若可
執行),並以 realpath 比對排除自身以防遞迴。`localfiles restore` 失敗 SHALL NOT
阻斷 checkout。

#### Scenario: checkout 後自動 restore

- **WHEN** 對一個被管理檔缺檔的 worktree 執行 `git checkout` 或 `git worktree add`
- **THEN** 全域 dispatcher 觸發,缺檔從 store 補齊

#### Scenario: 保留 repo-local hook

- **WHEN** repo 內存在可執行的 `.githooks/post-checkout`
- **THEN** dispatcher 在 restore 後仍呼叫該 repo-local hook(傳入原始 post-checkout 參數)
- **AND** dispatcher 不呼叫自身造成遞迴

### Requirement: 一次性安裝且 idempotent,不覆蓋既有自訂

設定 global `core.hooksPath` 的安裝 SHALL 為 idempotent:已指向目標目錄則跳過;
指向其他既有值時 SHALL 印警告且不覆蓋。hooks 目錄與 `localfiles` helper SHALL
由 chezmoi 管理(具可執行位),三平台(Windows/macOS/Linux)一致,Windows 下
git hooks 由 git-bash 執行。

#### Scenario: 重複 apply 不重設

- **WHEN** `core.hooksPath` 已是目標路徑且再次 `chezmoi apply`
- **THEN** 安裝腳本偵測後跳過,不重複寫入

#### Scenario: 既有非預期值不被覆蓋

- **WHEN** 使用者既有 `core.hooksPath` 指向其他目錄
- **THEN** 安裝腳本印警告並保留原值,不靜默覆蓋

### Requirement: bare-worktree reference 整合 local-files

`bare-worktree/setup.md` SHALL NOT 再指示設定 per-repo `core.hooksPath .githooks`
(因 repo-local config 覆蓋 global、會繞過 dispatcher),改為依賴全域 dispatcher
並交叉連結 `local-files/`。`bare-worktree/claude-state.md` 中「`.env` 無法自動
補齊」一節 SHALL 更新為指向 local-files 補齊機制。

#### Scenario: setup.md 不再設 per-repo hooksPath

- **WHEN** 讀者依 `bare-worktree/setup.md` 建立 bare+worktree 佈局
- **THEN** 步驟不含 `git --git-dir=.bare config core.hooksPath .githooks`
- **AND** 文件說明 hook 由全域 dispatcher 統一提供,並連結 `local-files/`

#### Scenario: claude-state.md 指向補齊機制

- **WHEN** 讀者讀到 claude-state.md 關於新 worktree 缺 `.env` 的說明
- **THEN** 該段交叉連結 `local-files/`,說明 restore 可自動補齊、缺的是「store 內也沒有」的情況

