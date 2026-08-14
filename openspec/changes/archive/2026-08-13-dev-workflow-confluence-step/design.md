## Context

`confluence-team-doc` 與 `dev-workflow` 目前各走各的。前者能建 ARCH / RUNBOOK、處理交叉連結與 hub 登記；後者完全沒提過它。兩者之間缺的是一個**啟動判準**。

三個既有事實限制了解法空間：

1. **Atlassian MCP 在 Claude 端是 user scope**（`~/.claude.json` 的 `mcpServers` 含 `atlassian`），每個 repo 都看得到。所以「MCP 在不在」無法當作「這個 repo 有沒有團隊文件空間」的鑑別測試。
2. **Codex 端根本沒有 Atlassian MCP**（`~/.codex/config.toml` 只有 openaiDeveloperDocs / context7 / codegraph / slack）。這是能力缺口，不是「還沒移植 skill」；且該 MCP 走 OAuth 互動登入，本來就 per-machine 不同步。
3. **`confluence-team-doc` 的座標寫死 `shoalteritbev`**（cloudId、spaceId、11 個 folder page ID），其 When-to-use 表明言其他 space 需先泛化。

同時，`context/principles.md` 有兩條直接管到這裡：「被學會忽略的 gate 比沒有 gate 更糟」，以及「關卡該不該自動掛,取決於它的訊號密度綁在什麼上」。

## Goals / Non-Goals

**Goals:**

- 讓「該寫團隊文件」這件事由判準觸發，而不是由記性觸發。
- 判準可機械套用——任何人（或任何 session）對同一個 change 得出同一個答案。
- repo 級的綁定只問一次，之後零成本。
- 兩處已知的能力落差顯性可見，不靜默消失。

**Non-Goals:**

- 不泛化 `confluence-team-doc` 的 space 座標。
- 不在 Codex 端補 Atlassian MCP 或移植該 skill。
- 不修 `~/.agent/workflow-registry.md` 既有的欄名語意 drift 與 slug 格式不一致（該檔 per-machine、不同步，修了只對這台機器有效，且與本 change 無關）。
- 不做 registry 的批次遷移；新欄位由流程在需要時補寫。

## Decisions

### D1. 觸發訊號綁「repo 外有沒有讀者」，不綁 diff

判準寫成一條可套用的問法：

> repo 外的人若要回答這次產出的那個問題（怎麼操作 / 為什麼這樣設計），除了讀這份 diff 之外有沒有別的地方可讀？**沒有 → 值得寫。**

**替代方案**：綁 change 的性質分類（架構決策→ARCH、運維程序→RUNBOOK、其餘不寫）——被否決，因為它只回答「寫成什麼」而不回答「該不該寫」，實際上把判斷推回個案直覺。綁流程規模（凡大型就問）——被否決，那是把訊號綁在工程量上，而工程量與別人需不需要知道沒有關係。

<!-- evergreen-candidate -->
**內容邊界因此補上第四格。** 現有三格的讀者全都在 repo 內：`specs/` = WHAT、`design.md` = 一次性決策、`context/` = 可重用的 domain 模型與原則（agent 做需求分析時讀）。Confluence 是同一條「讀者在哪」的軸上再延一格：**repo 外的讀者**。判準不必新發明，只是沿用既有的晉升邏輯。

### D2. 兩層閘門，粒度不同

| 閘門 | 粒度 | 承載 |
|---|---|---|
| **A · repo 綁定** | 一個 repo 問一次 | `~/.agent/workflow-registry.md` 的 `Doc Target` 欄 |
| **B · 本次值得寫** | 每個 change | D1 的判準，由模型在流程中套用 |

拆兩層是因為兩個問題的答案變動頻率差了幾個數量級。「這個 repo 對應哪個 Confluence 專案」幾乎永遠不變；「這次的產出有沒有外部讀者」每次都要重問。混成一題，不是每次重問不變的東西，就是把會變的東西快取住。

### D3. `Doc Target` 是三態，且空白與 `none` 語意不同

| 值 | 語意 | 行為 |
|---|---|---|
| 空白 | 尚未問過 | Gate B 判定值得寫時，一併問清楚並寫回 |
| hub 頁 URL 或 page ID | 有對應文件空間 | 交給 `confluence-team-doc` |
| `none` | 明確不需要 | 永遠不再提 |

空白與 `none` 必須分開。若合併成「沒填就是不需要」，這個功能永遠不會自己啟動，等於沒加；若合併成「沒填就是要問」，答過「不需要」的 repo 每次都會被重問。

### D4. Lazy 詢問——Gate B 判定值得寫時才問 Gate A

**讀** registry 發生在既有的 step 2b（零成本，那一步本來就會讀）。**問**延到 `finish-branch` 前、Gate B 判定值得寫的那一刻。

這個順序讓 `none` 在正確的時機被寫進去：模型判定值得寫 → 問 → 使用者說這個 repo 根本沒有對應的 Confluence → 記 `none` → 此後靜默。反過來若在 step 2b 就問，是在使用者還不知道這次會產出什麼的時候要他對一個抽象問題表態。

**替代方案**：eager（step 2b 發現空白就問）——被否決，每個新 repo 的第一條 workflow 都會多一個與當下工作無關的問題。

### D5. 掛在 review 迴圈收斂之後、`finish-branch` 之前，兩個流程都掛

掛點不能緊接在 `git:commit` 之後：review 可能開新一輪 change，先寫出去的頁面就過期，而 Confluence 是外部可見、改回來要人工。

兩個流程都掛，是 D1 的直接推論。handoff 原本假設「比照 `code:review-cross-model` 只掛大型」，但那個類比在 D1 定案後不成立——cross-model 的訊號綁 diff，diff 小就沒訊號，排除小型是對的；Confluence 的訊號綁讀者。改一行連線參數、產出一份別的團隊要照著操作的切換程序，是典型的小型 change 配 RUNBOOK。額外成本接近零，因為判定不值得時完全不出聲。

### D6. 決定權：模型判定並提案，使用者拍板；判定為否時不出聲

模型套 D1 的判準；判定值得寫 → 提出理由與建議標題，使用者可以否決；判定不值得 → 完全不提，不留痕。

**替代方案**：一律出聲含負面判定（「本次不寫，因為…」）——被否決。可審性確實較高，但每次都報告一句無事發生，兩週後就是視覺雜訊，連帶把真該出聲的那次一起洗掉。這正是「被學會忽略的 gate 比沒有 gate 更糟」。

文件型別（ARCH / RUNBOOK / KB）**不在此處決定**——`confluence-team-doc` 的 `references/doc-taxonomy.md` 已有 2-question rule 與封閉詞彙表。dev-workflow 只按啟動鍵，不複製那套規則（同一條規則不該寫進兩份 spec）。

### D7. 兩處顯性退化

<!-- evergreen-candidate -->
跨工具的能力落差要**顯性退化**，不能靜默不渲染。靜默的失敗方式是使用者跑完整條流程、以為流程完整，而少的那一格他根本不知道存在。既有前例是 `code:review-cross-model`「找不到對手時 degrade loudly 而非阻斷」。

1. **Codex 端**：共用 body 照常渲染這一步，Codex 的 name-map 把 token 映成明說的退化文字（本端無對應能力，需於 Claude 端執行）。
2. **非 `shoalteritbev` 目標**：`Doc Target` 在資料上不設限（可存任意 hub），但執行時若目標不是 `shoalteritbev`，明說該 space 尚未支援、需先泛化 `confluence-team-doc`，然後停下。

### D8. 釘住 registry 列「只增不減」

現況上 `~/.agent/workflow-registry.md` 確實只增不減（本機累積 12 列，最舊一列還停在早已淘汰的 `~/.claude/projects/…/memory` 路徑），但**沒有任何 spec 這樣斷言**。三態參數要靠它才成立，所以把不變量寫進 `workflow-concurrency`。

不釘的失效方式是靜默的：未來某個「清理 registry」的動作把列刪掉，表徵只會是「它又問我一次」，沒有人會把兩件事連起來。

### D9. name-map token 的形狀

共用 body 新增 token。Codex 端的退化文字是一整句，直接當單一 token 值塞進句子中間會讀不通，因此 body 的句型必須寫成兩端都成立。實作時先嘗試單一 token（Claude = skill 名、Codex = 退化句），若句型撐不住再拆成兩個 token（skill 名 + 可選的退化註記）。**兩端 name-map 都必須加上新 token**——漏加的渲染結果是空字串，且 `chezmoi apply` 不會報錯。

## Risks / Trade-offs

- **模型對 D1 判準的解讀會漂移** → 判準寫成單一問句而非形容詞清單，並在 spec 的 scenario 給正反各一例釘住兩端。
- **`Doc Target` 為空白的 repo 永遠等不到 Gate B 觸發，功能形同未啟用** → 這是 lazy 的設計代價，且方向正確：漏提而非誤報。使用者仍可隨時手動叫 `confluence-team-doc`，那次就會補寫 registry。
- **registry 是 per-machine 不同步的，換機器要重答一次** → 接受。它與 corp 識別資訊「留在機器本地狀態、不進 repo」的原則一致；同步反而會把 corp hub 座標帶進公開 repo。
- **判定為否時不出聲，因此誤判無法被使用者發現** → 接受。誤判的代價是一份沒寫的文件（可事後補），而一律出聲的代價是 gate 被學會忽略（不可逆地失去注意力）。
- **驗收要涵蓋兩端渲染** → `chezmoi execute-template` 分別渲染 Claude 與 Codex 的 SKILL.md，斷言新 token 渲染後非空；這正是 handoff 點名的坑。

## Open Questions

無。D9 的 token 形狀留到實作時依句型決定，不影響行為契約。
