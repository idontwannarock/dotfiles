## ADDED Requirements

### Requirement: OKF bundle 的 frontmatter 欄位子集

本 repo 宣告的 OKF v0.2 bundle 中,每個 concept 檔(即所有非 reserved filename 的 `.md`)SHALL 以 YAML frontmatter 開頭,欄位為 `type`、`title`、`description` 三者。`description` 的值 SHALL 加雙引號,以免含冒號時被 YAML 解析為 mapping。

concept 檔 SHALL NOT 帶 lifecycle 與 provenance 家族欄位。理由是 metadata 只表達非預設狀態:OKF §5.4 明定缺 `status` 即 `stable`;§5.5 的 `stale_after` 無預設值,缺此欄位即表示長青內容永不過期。

#### Scenario: concept 檔可被 OKF consumer 解析

- **WHEN** 掃描任一 OKF bundle 下所有非 reserved filename 的 `.md`
- **THEN** 每檔以 `---` 起始的 YAML frontmatter 開頭,且可被標準 YAML parser 解析
- **AND** 每檔含非空的 `type`、含 `title`、含加了雙引號的 `description`

#### Scenario: 不使用 lifecycle 與 provenance 欄位

- **WHEN** 檢視任一 concept 檔的 frontmatter
- **THEN** 不含 `status`、不含 `stale_after`
- **AND** 不含 provenance／trust 家族欄位(`sources`、`generated`、`verified`)

### Requirement: type 詞彙與擴充閘門

`type` SHALL 取自 `Playbook`(照著步驟做的程序)、`Reference`(機制與行為描述,供查詢)、`Principle`(規範性原則,供判斷)三者之一。切分軸線為「讀者拿它來做什麼」——做／查／判斷。

新增第四個 `type` 前 SHALL 先確認三個既有值皆不適用,且該新值 SHALL 可能有第二個成員。只會有單一成員的值不是分類,是換了位置的檔名。主題(如 `Git Layout`、`TDD`)SHALL NOT 用作 `type`,因主題已由目錄結構與檔名表達。

#### Scenario: 新增 type 前的確認

- **WHEN** 有人主張某 concept 檔需要第四個 `type` 值
- **THEN** SHALL 先逐一說明 `Playbook`、`Reference`、`Principle` 為何皆不適用
- **AND** SHALL 說明該新值未來可能有哪些其他成員;無法舉出第二個成員時 SHALL NOT 新增

#### Scenario: 排版形式不構成新 type

- **WHEN** 某 concept 檔以特定形式編排(如按術語索引的 glossary)但其內容為機制與行為描述
- **THEN** SHALL 歸為 `Reference`,SHALL NOT 為該排版形式新增 `type`

### Requirement: index.md 為 reserved filename,僅作目錄清單

依 OKF §3.1,`index.md` 與 `log.md` SHALL NOT 用作 concept document。任一 OKF bundle 下的 `index.md` SHALL 只包含兩種內容:**該目錄**涵蓋什麼範圍的簡短摘要(供讀者判斷要不要往下讀),以及有哪些內容、何時該讀哪一份的路由資訊。摘要 SHALL NOT 複述已在 concept 檔內的判準;重複的敘述會各自漂移。任何會被 agent 當作答案引用的知識 SHALL 置於具名的 concept 檔。

`index.md` SHALL NOT 路由該目錄以外的內容。指向其他目錄的清單屬於一個具名 concept 檔,因為它會被當作答案引用。

`index.md` 的連結 SHALL 依此規則產生:子目錄若有自己的 `index.md` 則連目錄,若無則直連其中的檔案。

`index.md` SHALL NOT 帶 frontmatter,唯一例外是 bundle root 的 `index.md` MAY 帶 `okf_version`。

#### Scenario: index 只路由本目錄

- **WHEN** 某段內容路由的是其他目錄的檔案清單
- **THEN** 該段 SHALL 置於具名 concept 檔,SHALL NOT 置於 `index.md`

#### Scenario: bundle root 宣告 OKF 版本

- **WHEN** 檢視任一 OKF bundle 的 root `index.md`
- **THEN** 其 frontmatter SHALL 僅含 `okf_version: "0.2"`
- **AND** 其內容 SHALL 涵蓋該 bundle 下全部 concept

#### Scenario: 非 root 的 index 不帶 frontmatter

- **WHEN** 檢視 bundle 內子目錄的 `index.md`
- **THEN** SHALL NOT 帶任何 frontmatter

### Requirement: 適用範圍守衛

本規範的適用範圍 SHALL 限於本 repo 明確宣告為 OKF bundle 的目錄。OKF frontmatter SHALL NOT 寫入各 tool 有自身 schema 的位置(`~/.claude/skills/`、`~/.codex/skills/`、`~/.claude/memory/`),因該處要求 `name` + `description` 而與 OKF 的必填 `type` 不交集,混放會導致 skill 被跳過或 Codex 解析錯誤。

#### Scenario: 不寫入 tool 自有 schema 位置

- **WHEN** 在 `~/.claude/skills/`、`~/.codex/skills/` 或 `~/.claude/memory/` 下新增或編輯檔案
- **THEN** SHALL NOT 寫入 OKF frontmatter,SHALL 使用該位置自身的 schema

#### Scenario: 宣告新 bundle

- **WHEN** 某目錄要成為新的 OKF bundle
- **THEN** SHALL 由某份 spec 明確宣告其為 OKF bundle,且該目錄 SHALL 有帶 `okf_version` 的 root `index.md`
