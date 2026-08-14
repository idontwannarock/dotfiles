## Context

`glossary.md` 早就有判準：知識依作用域分兩層，「換一個專案還成立嗎」——成立的進 machine-level（`~/.agent/reference/`），只屬本 repo 的進 repo-level（`context/`）。

repo 身分的定義顯然成立於每個專案，卻一直住在 `context/principles.md`。在只有人類讀它、或只有這個 repo 的 session 讀它的時候，這個錯層沒有代價。前一輪把一份**部署到每台機器、在每個 repo 執行**的 body 指向它，代價才顯現。

## Goals / Non-Goals

**Goals:**

- 算式住在每個 repo 都指得到的地方。
- `principles.md` 保留它真正的價值——為什麼、以及失敗長什麼樣——而不持有算式。
- body 與 spec 的每一處指路都是絕對路徑且字面一致。

**Non-Goals:**

- 不處理其餘三處確實的複述（`context/glossary.md`、`home/dot_agent/reference/local-files/store.md`、`home/.chezmoitemplates/skills/pickup.md`）。正典檔剛建立，把它們一併改是自然的下一步，但那會再擴一次範圍。
- 不動 `claude-memory-seed` 與 `local-files-store` 兩份實作規格裡的算式——它們規範一支腳本算出什麼，算式在那裡有正當性。

## Decisions

### D1. 正典進 `~/.agent/reference/`，不是把 body 改回自帶算式

body 自帶算式可以自足，但那是回到複本世界，而且是複本裡最容易漂移的一份（body 改動頻率最高）。

`~/.agent/reference/` 這層本來就是為此存在——`index.md` 明文寫著「各 tool 的 prompts 與 skills 以絕對路徑 link 進這棵樹」，`claude-state.md` 與 `dev-workflow-isolation.md` 已是同樣用法。

### D2. `principles.md` 留推理、去算式

<!-- evergreen-candidate -->
一條原則被拆成「算式」與「為什麼 + 失敗形狀」兩半時，兩半該分屬不同載體：算式是操作指令，要放在執行者指得到的地方；推理是判斷依據，要放在做需求分析時會讀的地方。`principles.md` 留下的那半仍然完整——它現在講的是「這個 bug 的共同形狀是不報錯、寫得出、只是看不到別人寫的」，那才是它在需求分析時的用途。

### D3. 正典檔明寫兩種捷徑，而不只寫正確作法

兩種捷徑（slugify 原始輸出、改用 `--show-toplevel`）都能通過隨手測試——前者在任何佈局下都「能用」，後者在 normal 佈局下與正解完全相同。只寫正確作法，讀者沒有理由懷疑自己記得的版本有問題。明寫失敗形狀，才讓「我記得是這樣」與「文件說不是」產生碰撞。

### D4. 本輪先實作後補記錄

這一輪是先改檔案、才建 openspec change。順序與流程規定相反，記在此處而非事後粉飾。成因是它源自 review 的第三輪修正，當下把它當成前一輪的收尾而非新一輪。spec 級變更仍需留下 change 記錄，故補建。

## Risks / Trade-offs

- **多一次檔案讀取**：模型要開 `~/.agent/reference/repo-identity.md` 才拿得到算式。接受——替代方案是讓一份高頻改動的檔案持有算式。
- **正典檔本身可能被漏讀**：body 明說「read it rather than reconstructing the rule from memory」，且 `~/.agent/workflows/` 底下既有目錄全為正典形式，任何自創推導在第一次比對時就露餡。
- **`agent-reference-layout` 的 scenario 只點名 bare-worktree 四檔**：新增葉檔不牴觸該 spec（它明寫「此處不宣告完整清單」），但 `index.md` 必須同步列出，否則 tree 有檔案不在索引上。
