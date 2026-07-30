## Context

`~/.agent/reference/`（chezmoi source: `home/dot_agent/reference/`）目前有 9 個純靜態 `.md`，零 frontmatter：

```
reference/
├── dev-workflow-isolation.md
├── bare-worktree/{index,operating,setup,claude-state}.md
├── local-files/{index,setup}.md
└── tdd/{tests,mocking}.md
```

由 `agent-reference-layout` capability 規範：純靜態複製（無 `.tmpl`、不經 `.chezmoitemplates/`）、以 `index.md` 作路由、各 tool 的 top-level prompt 以絕對路徑指過來。

外部約束來自 OKF v0.2 規範（`GoogleCloudPlatform/knowledge-catalog/okf/SPEC.md`）本身，其 §11 consumer conformance 全是「不准 reject」條款：MUST preserve unknown frontmatter keys、MUST tolerate broken cross-links、MUST NOT reject unknown `type`、MUST NOT reject 缺 `index.md` 的 bundle。這決定了導入的風險輪廓——**沒有任何 agent 會因為這批 frontmatter 而報錯，因為沒有任何 agent 對 OKF 有專屬解析邏輯**（Claude Code 與 Codex 官方文件皆無 OKF 字樣，現存支援全是社群 plugin）。

## Goals / Non-Goals

**Goals:**

- 讓 agent 只讀 frontmatter 就能判斷一份 reference 的種類與相關性，不必整檔載入。
- 讓這批知識成為結構上合格的 OKF v0.2 bundle，可被任何 OKF consumer 消費。
- 維持既有 inbound pointer 路徑穩定——`.chezmoitemplates/` 下的 skill 模板與 `user-system-prompt.md` 一行都不用改。

**Non-Goals:**

- 不導入 OKF 的 provenance / trust 家族（`sources`、`generated`、`verified`、trust tiers）。那套是為「跨組織交換知識、需判斷來源可信度」設計；此 bundle 是單人跨機器同步，作者與驗證者恆等於使用者本人。
- 不導入 `Attested Computation`（§10）——此 bundle 無可執行運算。
- 不引入 validator、CLI 或 plugin 相依。OKF 的 conformance 條件僅為「YAML 可解析 + 每個非 reserved `.md` 有非空 `type`」，可人工維持。
- 不動 `openspec/` 下的任何文件格式（見「Open Questions」）。

## Decisions

### D1：欄位集限縮為 `type` / `title` / `description`

OKF 唯一必填是 `type`；`title` / `description` 屬 recommended，且 §8 規定 index 條目「SHOULD include the description from the linked concept's frontmatter」——要讓 index 可自動生成就需要 `description`。

**排除 `status`**：§5.4 明定「Absent `status` ⇒ `stable`」。全數寫 `status: stable` 是 8 行零資訊量的雜訊。

**排除 `stale_after`**：§5.5 只寫 Optional，**未定義任何預設值**，配合 §11「consumers SHOULD derive staleness only from the fields specified」，缺此欄位即「永不過期」。規範並明確拒絕相對 TTL（「An absolute date, not a relative TTL, keeps the staleness decision a plain date comparison」），因此 OKF 根本無法表達「每 N 個月複審」。這批 reference 是長青機制文件，沒有失效點。

<!-- evergreen-candidate -->
**原則：metadata 只表達「非預設狀態」。** 有預設值的欄位就省略；沒有預設值的欄位，「不存在」本身即明確語意。全檔一律填同一個值等於把訊號稀釋成噪音——日後真的出現會過期的 reference（例如綁定特定產品版本的操作說明），它會因為是全 bundle 唯一帶 `stale_after` 的檔案而立刻醒目。

**Alternative considered**：填滿 recommended + lifecycle 全家族，「先有欄位以後好用」。否決——違反 dotfiles 的 surgical 原則，且製造需要定期回頭改的假訊號。

### D2：`type` 詞彙為 `Playbook` / `Reference` / `Principle`

OKF 不設中央 registry，`type` 由 producer 自定，consumer MUST 容忍未知值。依「讀者拿它來做什麼」分三類：

| `type` | 語意 | 檔案 |
|--------|------|------|
| `Playbook` | 照著步驟做的程序 | `bare-worktree/operating.md`、`bare-worktree/setup.md`、`local-files/setup.md`、`dev-workflow-isolation.md` |
| `Reference` | 機制與行為描述，供查詢 | `bare-worktree/claude-state.md`、`local-files/store.md` |
| `Principle` | 規範性原則，供判斷 | `tdd/tests.md`、`tdd/mocking.md` |

三個值涵蓋全部 8 個 concept，且切分軸線（做 / 查 / 判斷）與新檔歸類直覺一致。

**Alternative considered**：用主題當 `type`（`Git Layout`、`TDD`…）。否決——主題已由目錄結構表達，重複編碼且無助於 agent 判斷「這份文件要我做什麼」。

### D3：`local-files/index.md` 的實質內容搬到 `local-files/store.md`

OKF §3.1 將 `index.md` 列為 reserved filename 並規定 **MUST NOT be used for concept documents**；§8 進一步規定 index「contain no frontmatter」（唯一例外是 bundle-root 的 `okf_version`）。

現況二者不同命：

- `bare-worktree/index.md` 是**合格的 index**——scope 說明 + 「When to read which file」路由表，內容是關於該目錄的組織方式。原樣保留，不加 frontmatter。
- `local-files/index.md` 是**實質 concept**——authority model（global store 是備份、in-folder 是來源）、store layout、managed files、`localfiles` helper、agent read-fallback rule。這些是關於 local-files 機制本身的知識，不是目錄清單。

處置：內容搬到 `local-files/store.md`（`type: Reference`），原路徑改為薄的 §8 格式目錄清單，指向 `store.md` 與 `setup.md`。

<!-- evergreen-candidate -->
**原則：`index.md` 只放「這個目錄有什麼、何時讀哪個」，不放知識本身。** 任何一段內容如果會被 agent 當答案引用，它就屬於一個具名 concept 檔。這條界線讓 index 永遠可被自動生成或重建。

Inbound churn 只有一處（`bare-worktree/claude-state.md` 的相對連結），`.chezmoitemplates/` 無任何指向 `local-files/index.md` 的連結，故改名成本極低。

**Alternative considered**：留在 `index.md` 不管。否決——這是唯一一處實質不合規，而修正成本是一個連結；留著會讓「這個 bundle 是 OKF」的說法帶星號，未來自動生成 index 時還會踩到。

### D4：新增 bundle root `index.md` 承載 `okf_version: "0.2"`

`okf_version` 依 §8 只能放在 bundle-root `index.md`，而此 bundle 目前**沒有** root index。新增之，同時解決一個既存缺口：`dev-workflow-isolation.md` 與 `tdd/` 目前沒有任何可發現的入口，只能靠 skill 模板直接深連。

不新增 `tdd/index.md`——該目錄只有兩檔，root index 直接列出即可；等檔數成長再補。

**Alternative considered**：不宣告版本（§11 允許 consumer 對未宣告版本作 best-effort）。否決——root index 本身有獨立價值，順帶宣告版本零成本。

### D5：frontmatter 為靜態內容，不引入 template

`agent-reference-layout` 現有需求要求 source 端為純 `.md`。frontmatter 是固定字面值（無機器名、無路徑、無條件分支），故不觸發 `.tmpl` 需求。此決定寫入 spec 以免日後誤加。

## Risks / Trade-offs

- **把 OKF frontmatter 誤放進 agent 有自己 schema 的目錄** → 這批檔案全在中立的 `~/.agent/reference/`，不進 `~/.claude/skills/`、`~/.codex/skills/`、`~/.claude/memory/`。那些位置要求 `name` + `description`（Codex 另需 strict YAML），與 OKF 的必填 `type` 不交集，混放會導致 skill 被跳過或 Codex 解析錯誤。spec 明文界定適用範圍為 `~/.agent/reference/`。
- **`description` 含冒號未加引號** → YAML 會解析成 mapping 而炸。所有 `description` 值一律加雙引號，不論當下是否含冒號。
- **`type` 詞彙隨時間膨脹成一檔一類** → spec 要求新增 `type` 前先確認三個既有值都不適用；`type` 是為了分類，不是為了描述。
- **上游 OKF 仍在 v0.x，六週內就從 v0.1 跳到 v0.2** → 影響有限：所選三欄位是 v0.1 就存在的核心，v0.2 的新增全為 backward-compatible 的 optional 家族。`okf_version` 已宣告，未來升版是改一個字串。

## Migration Plan

單一 commit 即可完成，無中間狀態：

1. 8 個 concept 檔加 frontmatter；`local-files/index.md` → `store.md`（`git mv` 保留 history）。
2. 新增 root `index.md`（帶 `okf_version`）與薄的 `local-files/index.md`。
3. 修 `claude-state.md` 的相對連結。
4. `chezmoi apply` 驗證 `~/.agent/reference/` 實際生效（本 repo 的既有規則：先在當前電腦確認，才更新專案文件）。

Rollback：`git revert`。這批檔案無任何程式消費，frontmatter 移除即回到原狀。

## Open Questions

- `openspec/` 下的 artifact（`project.md`、`specs/*/spec.md`）是否也要 OKF 化？**本次不做**——OpenSpec 有自己的 artifact 生命週期與 schema 驗證，且上游正在把 `project.md` 遷往 `openspec/config.yaml` 的 `context:` 區段，格式歸屬未定。待該遷移落地後另案評估。
