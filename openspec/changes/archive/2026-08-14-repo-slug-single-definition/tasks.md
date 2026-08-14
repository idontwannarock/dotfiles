## 1. Spec 去除複本

- [x] 1.1 `首次在 repo 開啟 OpenSpec 流程` scenario 的推導改為指向 `principles.md`
- [x] 1.2 `在 worktree 中查詢 registry` scenario 同上
- [x] 1.3 `Active Workflows Index` requirement 的 `<repo-slug>` 括號說明改為指路
- [x] 1.4 新增 `推導算式不得出現在此 spec` scenario，把這條約束本身釘住

## 2. Body 去除複本

- [x] 2.1 ARCH dispatch table 的 auto-derive 欄改為指路，保留「bare+worktree 下自動推導是錯的」這個判斷
- [x] 2.2 2b 的 `derive the repo slug from ...（slugify the result with /→-）` 改為指路
      → 並補上為何不能直接 slugify raw 輸出（尾端是 `.git`/`.bare`，得到的是另一個目錄名）。

## 3. 驗收

- [~] 3.1 `slug(dirname(realpath` 在 `principles.md` 以外零命中（排除 archive）
      → **未達成，且判準本身訂得過寬。** 本 change 的目標範圍（`workflow-concurrency` spec 與
        `dev-workflow` body）已零命中。但全庫另有 5 處非 archive 的複本：
        `context/glossary.md:38`、`openspec/specs/local-files-store/spec.md:11`、
        `openspec/specs/claude-memory-seed/spec.md:48`、
        `home/dot_agent/reference/local-files/store.md:40`、
        `home/.chezmoitemplates/skills/pickup.md:7`。
        全部早於本次工作。其中 `claude-memory-seed` 與 `local-files-store` 是**實作規格**——
        它們規範一支腳本算出什麼，算式寫在那裡有其正當性，與「流程指令複述規則」不同性質。
        `glossary.md`、`store.md`、`pickup.md` 三處則確實是複述。
        **不在本 change 擴張處理**：那會把一個三行的一致性修正變成跨五個 capability 的重構。
- [x] 3.2 `git rev-parse --git-common-dir` 在 spec 與 body 中僅用於非 slug 推導用途
      → `dev-workflow` 剩兩處：ARCH 偵測與 2c 的 stale 清理，皆非 slug 推導；
        2b 新增的那處是反面警告（「never slugify ... raw」），不是推導指令。
- [x] 3.3 兩端 `chezmoi execute-template` 渲染成功，無未解析 token
- [x] 3.4 `openspec validate --all` 全綠（37/37）
