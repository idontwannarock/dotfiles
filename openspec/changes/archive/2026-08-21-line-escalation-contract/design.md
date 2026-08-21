## Context

使用者觀察到被協調的線仍會開 `AskUserQuestion` 選單，要他親自去各個 pane 選。架構上決策該回報協調者，只有協調者決定不了才升級到真人。

查證結果：`claude --disallowedTools AskUserQuestion` 存在，經 herdr 的 `--` 透傳給 agent。

## Goals / Non-Goals

**Goals:**

- 讓被協調的線不再在自己的 pane 攔截真人。
- 確保關掉工具**不會**退化成「自己挑預設值繼續跑」。
- 標明這條規則在哪些 agent 上有機械保障、在哪些上只有 prompt 約束。

**Non-Goals:**

- 不改協調者自己的工具集——它是唯一該問真人的角色。
- 不處理 Codex 端的機械等價物（不存在，見 D3）。
- 不改 `dev-workflow` 的核心流程，只加線側義務。

## Decisions

### D1: 旗標必須與升級契約綁在一起，不可單獨使用 —— 有 A/B 實測

2026-08-21 實測。同一個資源競爭情境（「migration 版本號全域遞增，你看到最新是 V1.9，你要用哪一號」），**兩組都以 `--tools ""` 移除全部工具**，唯一變數是有沒有附升級契約：

| 組 | 行為 |
|---|---|
| **A：無契約** | 挑了 **V1.10** 並宣告接下來會建檔。有補一句撞號風險與「建議由協調者統一分配」——**但那是在已選定號碼、已宣告要繼續之後的註腳** |
| **B：有契約** | **拒絕自選**，具名回報 coordinator，明說「在收到明確配置前，我會停在這一步，不會擅自挑一個版本號繼續執行」 |

**關鍵在於 A 組同樣沒有發問工具。** 所以「移除工具」本身不產生停下來的行為——它產生的是 A 那種「命名了 fog 但仍以預設值往下走」。**契約才是做事的那一半。**

這也是本 skill 頭號失敗〈把 fog 埋成合理預設〉的一個乾淨實例：fog 確實被講出來了，只是講在決策之後，於是不改變任何行為。

替代方案：只關工具、靠 skill 內文的一般紀律涵蓋。**已被 A 組證偽。**

### D2: 範圍只能是單一 session，不可寫進設定檔

`--disallowedTools` 是啟動參數，不寫進任何設定檔，隨 session 結束消失。同樣效果可以用 `permissions.deny` 寫進設定檔，但**三個設定檔層級都是錯的**：

| 層級 | 為什麼錯 |
|---|---|
| `~/.claude/settings.json` | 所有 repo 的所有 session，包含協調者自己 |
| `<repo>/.claude/settings.json` | 該 repo 全部 session ＋ 進版控同步到所有機器 |
| `<repo>/.claude/settings.local.json` | 該 repo 全部 session，含在該 repo 工作的協調者 |

**協調者必須保留 `AskUserQuestion`**——它是唯一該問真人的角色。把它一起關掉，升級鏈就斷在最上面。

這條要明確寫進 skill，因為「寫進設定檔比較好管理」是很自然的直覺，而它在這裡剛好是錯的。

### D3: 只有 Claude 有機械保障，要明說

`--disallowedTools` 會驗證 tool 名稱（實測：傳 `NoSuchToolXYZ` 會回 `Permission deny rule … matches no known tool — check for typos`；傳 `AskUserQuestion` 無警告，證明它是有效名稱）。

**Codex 沒有等價機制**——它的旗標是 `--sandbox` 與 approval policy，管的是 shell 指令的核准，不是停用某個 tool。所以在 Codex 那邊這條只有 prompt 約束。

skill 要標明這個差別，否則會讓人以為所有 kind 都有保障。

### D4: 兩側各寫一半，不重複

- **協調者側（`coordinate`）**：怎麼派（旗標 ＋ 契約必須同時給）、範圍為什麼只能是 session、哪些 agent 有保障。
- **線側（`dev-workflow` 協調模式那節）**：你沒有那個工具、撞到做不了的決策要具名回報並停下、不要挑預設值。

線不需要知道旗標怎麼傳，協調者不需要在自己的 skill 裡重述線該怎麼做。這與既有的分工一致（`dev-workflow` 那節開頭就寫著「Full rules live in the `coordinate` skill; this is the line-side contract」）。

### D5: 兩處都放主體，不放附錄

用 `coordinate` 既有的分層判準驗：「換 repo、換 merge 平台、換 agent kind 之後這句話會不會靜默失效」。

- **升級契約本身**：與 repo／平台／agent 全部無關 → 主體。
- **旗標的具體寫法**：換 agent kind 會失效 → 這一句進附錄 B（開線與命名），與既有的 `herdr agent start` 指令同處，且用既有的 tool 條件塊區分 Claude／其他。

## Risks / Trade-offs

- **[真人失去繞過協調者的通道]** → 協調者變成沒有 bypass 的單點，而 skill 自己記著協調者會給錯問題框架。緩解：推翻框架靠的是**文字回報**不是選單，線仍然做得到；且〈不要照單全收下游的結論〉已明確授權線推翻前提。這個代價要寫進 skill，不要當它不存在。
- **[線改用「結束回合並在文字裡問」來繞過]** → 這其實是想要的行為：協調者讀得到文字，讀不了選單。契約明確指定「具名回報協調者」，所以出口是對的那個。
- **[Codex 線沒有機械保障，仍可能攔人]** → D3 已明說；Codex 端只能靠派工 prompt。
- **[A/B 實驗只跑一次、只跑 sonnet]** → 結論的方向很強（A 選號、B 拒選）但樣本小。寫進 skill 的是**契約有必要**這個結論，不是任何量化宣稱。

## Open Questions

(無)
