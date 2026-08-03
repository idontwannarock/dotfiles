## Context

`context/` 目前對跨工具 parity 的描述停在抽象層:

- `glossary.md` 的 **cross-tool parity / name-map wrapper** 條目 —— 「chezmoi shared body + 每工具一個薄的 name-map wrapper」,並指路「目標工具是 Claude 與 Codex(未來或加 Antigravity CLI);Gemini CLI 已放棄」。
- `principles.md`(「跨平台與跨工具部署」組)的 **跨工具 parity = shared body + 薄指標** —— 「權威 body 一份在 `~/.agent` / `.chezmoitemplates`,每工具一個 name-map wrapper。目標工具清單見詞彙表。」

兩處都沒指名鏈上的檔案。實地驗證(本次)鏈仍成立:

```
home/.chezmoitemplates/user-system-prompt.md   ← 單一來源(4559 bytes)
  ├─ home/dot_claude/CLAUDE.md.tmpl            ← 55 bytes,`{{ template "user-system-prompt.md" . -}}`
  └─ home/dot_codex/AGENTS.md.tmpl             ← 55 bytes,同上
```

缺口來源是 auto-memory `project-cross-tool-targets`(寫於 2026-06-15)。該 memory 的「目標工具清單」那半已被 `glossary.md` 完整取代,剩下的就是本次要補的兩條。

`grep -rniE 'antigravity|gemini|thin pointer|user-system-prompt' context/ docs/` 於 2026-07-31 與 2026-08-03 兩次確認:除 `glossary.md:31` 的抽象描述與 `docs/claude-code.md` 兩處 `openspec --tools` 旗標外,repo 文件無涵蓋。

## Goals / Non-Goals

**Goals:**

- 讓「這條鏈是哪些檔案」在 `context/` 可查,不必反推。
- 讓「接新工具的前置檢查」成為可套用的判準,而非口耳相傳。
- 落地後回收 `project-cross-tool-targets` memory,消除同一事實的第二份副本。

**Non-Goals:**

- 不描述 `user-system-prompt.md` 的**內容**。那份 body 會隨時間變動,寫進 `context/` 會讓「長青」失效。本次只固定鏈的**形狀**。
- 不動 chezmoi source。`context/` 不在 `.chezmoiroot` 之下,不部署,無需 `chezmoi apply`。
- 不實際接 Antigravity。第 2 條是前瞻性防呆,不是現況描述。

## Decisions

### D1:兩條各自落在哪 —— 套 `project-context` 的三步判定

| | 第 1 條(具名鏈) | 第 2 條(前置檢查) |
|---|---|---|
| 讀者能照做? | 能(接新工具時照這個結構做),但 `context/` 已有抽象對應條目 | 能,且 `context/` 無對應條目 |
| 換工具/情境即不成立? | 否 —— 它就是跨工具骨架本身 | 否 —— 對任何新工具都成立 |
| 判定 | `context/` | `context/` |

根判準(同一事實改變時要動的檔案數 SHALL 為一)在此是決定性的:第 1 條若落 `docs/`,`claude-code.md` 與 `codex-cli.md` 各要寫一份,鏈一改要動兩處 —— 直接出局。落 `context/` 才有唯一落點。

**第 1 條進 `glossary.md`**:它是模組邊界事實(誰是 source of truth、誰是 wrapper),正是詞彙表的職責;且 `principles.md` 那條已寫「目標工具清單見詞彙表」,把具名鏈放同一處與既有指路方向一致。

**第 2 條進 `principles.md`**:是跨 change 反覆適用的判斷依據,屬「跨平台與跨工具部署」組。

### D2:就地擴充既有條目,不新起條目

兩條都不新增條目。

- 第 1 條若在 `glossary.md` 另起一個術語,會與 **cross-tool parity / name-map wrapper** 講同一件事,違反「一條規則不寫兩處」。
- 第 2 條是「shared body + 薄指標」那條的自然推論 —— 要用薄指標,得先知道指標檔叫什麼。附在該條之後比獨立成條更能表達從屬關係,也讓 `principles.md` 維持 PR #45 的 23 條分四組結構不變。

替代方案(各自新起一條)被否決的理由是它讓兩份文件的條目數成長,而新增的資訊量是句子級的;`principles.md` 剛在 PR #45 從 25 條精簡到 23 條,反向膨脹需要更強的理由。

### D3:`~/.agent/reference/` 那半也補進第 1 條

memory 的配套規則「共用 body 之外的知識放 `~/.agent/reference/`,各工具用 thin pointer 取用」在 `glossary.md` 已有 **`~/.agent` shared body** 與 **兩層 context** 兩個條目涵蓋。因此第 1 條只需**指向**它們,不重述 —— 否則就是同一事實的第三份副本。

### D4:memory 回收與索引同步

`project-cross-tool-targets.md` 落地後無唯一內容,整份刪除。**同時刪 `MEMORY.md` 的索引行** —— 只刪檔不刪索引就留下斷鏈,而本案的起因正是這類斷鏈。驗收:`MEMORY.md` 每一行都指向存在的檔案。

### D5:auto-memory 邊界用 ADDED 而非 MODIFIED

既有的「內容邊界與晉升閘門」requirement 陳述四分法。auto-memory 是**新增的關注面**,不是四分法的既有陳述有錯 —— 用 MODIFIED 得整段搬移那個很長的 requirement 區塊,而 OpenSpec 明列的常見陷阱正是「MODIFIED 帶部分內容導致 archive 時遺失細節」。故獨立成一條 ADDED。

這條也刻意**不寫成檔案樹斷言**(不寫「`glossary.md` SHALL 指名三個檔案」之類)。那種寫法把當下的檔案結構凍結成需求,鏈一改就 drift,且遇到新案例無從套用 —— 正是 `principles.md`「規範要寫成可機械套用的規則」那條點名的反模式。寫成載體性質的規則後,它同時涵蓋本次與未來任何一條孤懸在 memory 的事實。

## Risks / Trade-offs

- **鏈的檔名日後漂移,`context/` 變成錯的指路** → 這正是把它寫進版控文件而非 memory 的理由:memory 漂移無人察覺,`context/` 的錯誤會在 code review 與下次 `grill` 讀到時暴露。且只固定形狀不固定內容(見 Non-Goals),漂移面已最小化。
- **在非 sync/archive 階段寫入 `context/`** → 不成立。本次走完整 OpenSpec 流程,寫入發生在 `openspec-sync-specs`/archive 階段。晉升閘門要的證據等級也已滿足:兩條都有已 ship 的實作背書(三個檔實地驗證存在、鏈確實運作),不是「我們覺得應該這樣」。
- **刪 memory 後若 PR 未合併,事實會短暫無處可查** → 收尾順序固定為「PR 合併後才刪 memory」,不在 PR 內做。
