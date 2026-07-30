## MODIFIED Requirements

### Requirement: index.md 為 reserved filename，僅作目錄清單

依 OKF §3.1，`index.md` 與 `log.md` SHALL NOT 用作 concept document。`~/.agent/reference/` 下任一 `index.md` SHALL 只包含兩種內容：該目錄涵蓋什麼範圍的一句話摘要（供讀者判斷要不要往下讀），以及有哪些內容、何時該讀哪一份的路由資訊。任何會被 agent 當作答案引用的知識 SHALL 置於具名的 concept 檔。

`index.md` 的連結 SHALL 依此規則產生：子目錄若有自己的 `index.md` 則連目錄，若無則直連其中的檔案。

`index.md` SHALL NOT 帶 frontmatter，唯一例外是 bundle root 的 `~/.agent/reference/index.md` MAY 帶 `okf_version`。

#### Scenario: bundle root index 宣告 OKF 版本並列出全部內容

- **WHEN** `chezmoi apply` 執行
- **THEN** `~/.agent/reference/index.md` 存在，frontmatter 僅含 `okf_version: "0.2"`
- **AND** 其內容涵蓋 bundle 下全部 concept：`bare-worktree/` 與 `local-files/` 因各有 `index.md` 而以目錄形式連結，`tdd/` 因無 `index.md` 而直連 `tests.md`、`mocking.md`，root 層的 `dev-workflow-isolation.md` 直連

#### Scenario: local-files 的機制知識脫離 index.md

- **WHEN** 讀者開啟 `~/.agent/reference/local-files/`
- **THEN** `store.md` 存在且帶 `type: Reference` frontmatter，內含 authority model（global store 為備份、in-folder copy 為來源）、store layout、managed files、`localfiles` helper 與 agent read-fallback rule
- **AND** `index.md` 僅為指向 `store.md` 與 `setup.md` 的目錄清單，不帶 frontmatter
- **AND** 無任何檔案連結指向已不存在的 `local-files/index.md` 內容段落

#### Scenario: bare-worktree 的架構判準脫離 index.md

- **WHEN** 讀者開啟 `~/.agent/reference/bare-worktree/`
- **THEN** `scope.md` 存在且帶 `type: Reference` frontmatter，內含此 reference 只涵蓋一種架構的判準：`basename "$(git rev-parse --git-common-dir)"` 的 `.git` vs `.bare` 分派、layout×discipline 的 2×2 空間、以及未填格子出現時的處置
- **AND** `index.md` 僅含一句話範圍摘要與「When to read which file」路由表，該表包含 `scope.md` 一列
- **AND** `index.md` 不含 dispatch 規則、2×2 分析或任何前瞻決定的內文
