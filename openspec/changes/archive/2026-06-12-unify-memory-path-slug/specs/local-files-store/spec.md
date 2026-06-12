## MODIFIED Requirements

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
