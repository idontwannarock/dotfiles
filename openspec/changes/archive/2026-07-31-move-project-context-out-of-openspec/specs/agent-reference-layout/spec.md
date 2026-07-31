## ADDED Requirements

### Requirement: ~/.agent/reference/ 為 OKF v0.2 bundle

`~/.agent/reference/` SHALL 為一個 OKF v0.2 bundle,其 frontmatter 欄位、`type` 詞彙、`index.md` 的 reserved 地位與內容邊界 SHALL 遵循 `okf-bundle-conventions`,本 spec SHALL NOT 重述該格式規則。

本 spec 僅規範此 bundle 專屬的內容組成:哪些知識屬於哪個檔、root `index.md` 涵蓋哪些項目。

#### Scenario: bundle root index 涵蓋全部內容

- **WHEN** `chezmoi apply` 執行
- **THEN** `~/.agent/reference/index.md` 存在,frontmatter 僅含 `okf_version: "0.2"`
- **AND** 其內容涵蓋 bundle 下全部 concept:有自身 `index.md` 的子目錄以目錄形式連結,無 `index.md` 的子目錄直連其中檔案,root 層的檔案直連

#### Scenario: local-files 的機制知識脫離 index.md

- **WHEN** 讀者開啟 `~/.agent/reference/local-files/`
- **THEN** `store.md` 存在且帶 `type: Reference` frontmatter,內含 authority model(global store 為備份、in-folder copy 為來源)、store layout、managed files、`localfiles` helper 與 agent read-fallback rule
- **AND** `index.md` 僅為指向 `store.md` 與 `setup.md` 的目錄清單,不帶 frontmatter

#### Scenario: bare-worktree 的架構判準脫離 index.md

- **WHEN** 讀者開啟 `~/.agent/reference/bare-worktree/`
- **THEN** `scope.md` 存在且帶 `type: Reference` frontmatter,內含此 reference 只涵蓋一種架構的判準:`basename "$(git rev-parse --git-common-dir)"` 的 `.git` vs `.bare` 分派、layout×discipline 的 2×2 空間、以及未填格子出現時的處置
- **AND** `index.md` 僅含簡短的範圍摘要與「When to read which file」路由表,該表包含 `scope.md` 一列
- **AND** `index.md` 不含 dispatch 規則、2×2 分析或任何前瞻決定的內文

## REMOVED Requirements

### Requirement: reference concept 檔帶 OKF v0.2 frontmatter

**Reason**: 本 repo 出現第二個 OKF bundle(`context/`)後,格式規則由兩處共用,留在本 spec 會產生第二份而必然漂移。已抽出為獨立 capability。

**Migration**: 見 `okf-bundle-conventions` 的「OKF bundle 的 frontmatter 欄位子集」與「type 詞彙與擴充閘門」。規則實質不變;原「適用範圍限於 `~/.agent/reference/`」放寬為「限於本 repo 宣告的 OKF bundle」,對 tool 自有 schema 位置的禁令原文保留於「適用範圍守衛」。

### Requirement: index.md 為 reserved filename，僅作目錄清單

**Reason**: 同上,`index.md` 的 reserved 地位與內容邊界是所有 OKF bundle 共用的格式規則。

**Migration**: 見 `okf-bundle-conventions` 的「index.md 為 reserved filename,僅作目錄清單」。此 bundle 專屬的內容組成(root index 涵蓋範圍、`local-files/store.md`、`bare-worktree/scope.md`)保留於本 spec 新增的「~/.agent/reference/ 為 OKF v0.2 bundle」。抽出時另新增一條通則:`index.md` SHALL NOT 路由該目錄以外的內容。
