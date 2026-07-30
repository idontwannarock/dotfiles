## Context

`~/.agent/reference/` 已是 OKF v0.2 bundle。前一個 change 立了一條界線但只執行了一半：

| 檔案 | 前一個 change 的判定 | 實際 |
|------|---------------------|------|
| `local-files/index.md` | concept → 搬到 `store.md` | ✅ 正確 |
| `bare-worktree/index.md` | 「合格的 index」→ 原樣保留 | ❌ 43 行裡有 24 行是 concept |

判定失誤的成因可追溯：`local-files/index.md` 被逐行讀完才判定，`bare-worktree/index.md` 只掃了尾段的路由表。**同一個判準沒有用同樣的力氣施加在每個候選上。**

## Goals / Non-Goals

**Goals:**

- 讓 `bare-worktree/` 與 `local-files/` 受同一判準處置，消除 bundle 的內部不一致。
- 讓 spec 的斷言與實作逐字相符。
- 把「index 連什麼」從個案判斷變成可機械套用的規則。

**Non-Goals:**

- 不把 root index 接進任何 tool 的 prompt（獨立設計題，見 proposal）。
- 不新增 `tdd/index.md`。
- 不重寫 archive 內的歷史紀錄 —— 前一個 change 的 design.md 保留它當時的錯誤判定，那是決策軌跡。

## Decisions

### D1：Scope 段搬到 `scope.md`，index 留一句摘要 + 路由表

`## Scope — why only this one architecture` 的內容分兩種性質，搬移時要分開處置：

- **「為什麼這個 reference 只涵蓋一種架構」的判準**（dispatch 規則、2×2 分析、未填格子的前瞻決定）→ 這是 agent 會引用的知識，進 `scope.md`。
- **「這個目錄涵蓋什麼範圍」的一句話**（本 reference 記錄 bare+worktree 對預設 layout 的偏離）→ 這是讀者決定要不要往下讀的判斷依據，留在 index。

`scope.md` 的 `type` 取 `Reference`：它描述的是既有架構空間的形狀與邊界，不是照著做的步驟（`Playbook`），也不是規範性原則（`Principle`）。

**Alternative considered**：整段搬走，index 只留路由表。否決——讀者會失去「這個目錄跟我有沒有關係」的第一道篩選，而那正是 §8 progressive disclosure 的用途。

### D2：index 連結規則 —— 有 `index.md` 的目錄連目錄，沒有的連檔案

前一個 change 的 spec 斷言 root index 列出三個子目錄，實作卻對 `tdd/` 連檔案。兩者都不算錯，錯的是沒有規則所以無法判斷哪個對。

定為：**子目錄有自己的 `index.md` 就連目錄（讓漸進揭露多一層）；沒有就直連檔案（避免連到會 dead-end 的目錄）。** 依此，`bare-worktree/`、`local-files/` 連目錄，`tdd/` 連檔案 —— 實作不動，改 spec 措辭。

<!-- evergreen-candidate -->
**原則：規範要寫成可機械套用的規則，不是個案判斷。** 「列出三個子目錄」這種斷言把當下的實作狀態誤當成規範；一旦目錄增減就 drift。寫成「有 index 連目錄、沒有連檔案」則同時涵蓋現況與未來，且任何人都能得出同一個答案而不需要問作者。

**Alternative considered**：加 `tdd/index.md` 讓三個子目錄一致。否決——兩個檔案包一層 index，frontmatter 與維護成本超過內容本身，正是前一個 change 的 design.md 明文警告的過度拆分。

### D3：以 `--amend` 修正前一個 commit 的 message，不另開 commit

該 commit 尚未 push，amend 無 history rewrite 風險。錯誤宣稱留在 message 裡的代價是永久的：日後有人讀 `git log` 會以為 root index 已經被接上，從而不去修真正的缺口。

## Risks / Trade-offs

- **搬移時漏內容** → `scope.md` 的正文須與原 `index.md:10-33` 逐行對照；驗證方式是「原 24 行每一行都對應到 `scope.md` 的某一行」。
- **index 摘要與 `scope.md` 重複** → index 只留一句話，不複製判準；重複的敘述會各自漂移。
- **root index 的缺口仍在** → 本 change 只修正誇大的宣稱，不修缺口。缺口本身記在 proposal 的「明確不做」，避免它被當成已解決。

## Migration Plan

1. 建 `scope.md`，把 `index.md:10-33` 搬過去並加 frontmatter。
2. 縮減 `index.md` 至摘要 + 路由表，並在路由表加一列 `scope.md`。
3. 改 spec 兩處。
4. `chezmoi apply ~/.agent/reference` + 驗證。
5. `git commit --amend` 修 message，再 commit 本 round 的變更。

Rollback：`git revert` 或把 `scope.md` 併回 index。無程式消費這些檔案。
