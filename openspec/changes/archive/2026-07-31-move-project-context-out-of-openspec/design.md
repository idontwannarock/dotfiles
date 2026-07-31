## Context

`openspec/project.md` 由 PR #16 建立,是給需求分析用的長青 context 文件(三分法邊界 + 晉升閘門)。它從一開始就放在 `openspec/` 底下,但那個位置是歷史決定而非設計決定。

現況查證:

- **OpenSpec CLI 1.1.1 不依賴此路徑。** `openspec/config.yaml` 與 `~/.agent/bin/ensure-openspec.sh` 皆無提及,CLI 不讀、不寫、不重建它。`openspec/` 底下實際受 CLI 管轄的只有 `specs/` 與 `changes/`。
- **上游 CLI 另有 `config.yaml` 的 `context:` 欄位**,是 CLI 主動建議的 project-context 承載處,但已否決(見 D7)。
- **`.chezmoiroot=home/`** 使 repo root 成為「不部署到任何機器的專案基礎建設區」,與 `openspec/`、`docs/`、`tools/` 同層。
- **PR #41 剛把 `~/.agent/reference/` 轉成 OKF v0.2 bundle**,確立了 `type` 三值詞彙(`Playbook`/`Reference`/`Principle`)、`index.md` 為 reserved filename、frontmatter 欄位子集三項慣例。
- **inbound 引用 9 處**,分佈於 4 份 spec、2 份 `docs/`、3 份 `.chezmoitemplates/skills/`。其中三份 skill body 會經 chezmoi 渲染到使用者機器。

## Goals / Non-Goals

**Goals:**

- 讓 repo-level context 的位置反映它的真實身分:專案文件,不是 OpenSpec CLI 的一部分。
- 讓 machine-level(`~/.agent/reference/`)與 repo-level(`context/`)兩層 context 共用同一組 `type` 詞彙、同一套 `index.md` 慣例,agent 只讀 frontmatter 即可判斷相關性。
- 搬移過程零內容遺失,且 review 時可逐段對照。

**Non-Goals:**

- **不精簡或改寫內容。** 原則段 20 條確有可壓縮處,但與搬家混在同一個 PR 會讓 reviewer 無法分辨某行消失是搬移疏漏還是刻意刪除。列為後續 change。
- **不把 bundle root 接進各 tool 的 prompt。** 那會改變每個 session 的載入行為與 token 成本,是獨立設計題。現行讀取方式不變:`grill` 與 `arch-review` 在需要時主動讀,非自動載入。
- **不回溯改寫 archived changes。** 其中對 `openspec/project.md` 的提及是當時的事實記錄,凍結。
- **不新增 root `CONTEXT.md`。**
- **不處理 `docs/` 與 `context/` 的概念段落重疊。** 見下方「後續 change 候選」。

## Decisions

### D1:目標為 repo root 的 `context/`

三分法(`openspec/specs/`=WHAT、change 的 `design.md`=一次性、context=domain)的第三隻腳應與前二者平級。

**Alternative considered**:`docs/context/`。否決 —— `docs/` 現為 16 份平鋪的 how-to guide,塞入一個帶 frontmatter、`index.md` 為 reserved filename 的 OKF bundle,會使同一目錄有兩套契約,之後每新增 `docs/*.md` 都要先判斷「這要不要 OKF」。一次性的「root 多一個目錄」成本低於持續產生的判斷成本。

**Alternative considered**:`.context/`(隱藏)。否決 —— 這份文件的既有問題正是「人不知道它存在」。

### D2:拆成 4 個 concept 檔 + 1 個純路由 `index.md`

原四段的映射:「這是什麼」→ `overview.md`、「詞彙表」→ `glossary.md`、「反覆適用的原則與約束」→ `principles.md`、「方位:能力面在哪」→ `capability-map.md`。`index.md` 為新寫。

原計畫是讓「方位」段直接充當 `index.md`,已否決:該段路由的是**另一個目錄**(`openspec/specs/`)的內容,且會被 agent 當答案引用(「statusline 的行為契約在哪」),兩者皆違反 `index.md` 只列本目錄、不放知識的界線。

### D3:`capability-map.md` 的重點是分組,不是列舉

原「方位」段列出 29 個 spec 名。逐個列舉會隨 spec 增減 drift,且 `openspec spec list` 就能產生 —— 正是既有原則「規範要寫成可機械套用的規則,不是個案判斷」警告的「把當下的檔案樹凍結成需求」。

改為以**能力分組與各組邊界**為主體(chezmoi 骨架／provisioning／外部版本與鏡射／statusline／開發流程／記憶與本機檔案／上手)。分組不可由 `ls` 推導,是真正的 domain 知識;新 spec 落入既有分組時不必改檔。

順帶修正:`project-context-doc` 本身漏列於原分組中 —— 管 `project.md` 的 capability 沒出現在 `project.md` 的能力清單上。

### D4:不新增 `type: Concept`,`glossary.md` 用 `type: Reference`

`agent-reference-layout` 要求新增第四個 `type` 前先確認三個既有值皆不適用。確認結果為**適用**,兩層理由:

1. 三值的切分軸線是「讀者拿它來做什麼」——做／查／判斷。詞彙表的用途是查,且其詞條內容本身即機制與行為描述(如 `.chezmoiroot` 條目描述雙向分界的運作),符合 `Reference`(「機制與行為描述,供查詢」)。glossary 是**按術語索引的排版形式**,不是新的知識種類。
2. `Concept` 在 OKF 中已被佔用:§3.1 將所有非 reserved filename 的 `.md` 稱為 *concept document*。`type: Concept` 對 bundle 內每一個檔都成立,鑑別力為零,命中 PR #41 記下的反模式「`type` 是為了分類,不是為了描述」。

本 bundle 的 type 分布為三個 `Reference` + 一個 `Principle`。分布不均不構成細分詞彙的理由:四檔的差異已由檔名表達,`type` 不必再編碼一次(同 PR #41 否決「用主題當 type」的理由)。

<!-- evergreen-candidate -->
**原則:一個分類欄位若「每個新檔都想新增一個值」,它就不是分類欄位,而是換了位置的檔名。** 判準是問「這個值會不會有第二個成員」。這與既有的「metadata 只表達非預設狀態」是同一個病的兩種症狀 —— 前者稀釋訊號,後者消滅訊號。

### D5:抽出 `okf-bundle-conventions` capability

搬完後 repo 有兩個 OKF bundle,共用 5 條格式規則(frontmatter 欄位子集、`type` 詞彙與擴充閘門、`description` 引號規則、`index.md` reserved 地位與內容邊界、bundle root 的 `okf_version`)。抽成獨立 capability,`agent-reference-layout` 瘦身為部署位置與檔案拆分規則,`project-context` 只管內容邊界與晉升閘門,兩者各引用格式 capability 一次。

適用範圍守衛句由「限於 `~/.agent/reference/`」改寫為「限於本 repo 宣告的 OKF bundle」。原句存在的理由(防止 OKF frontmatter 寫進 `~/.claude/skills/`、`~/.codex/skills/`、`~/.claude/memory/` 等有自身 schema 的位置)不變,禁令原文保留。

**Alternative considered**:單向引用(context spec 寫「格式 SHALL 遵循 `agent-reference-layout` 所定義的規則」,只放寬那句適用範圍)。最省改動,但使 `agent-reference-layout` 這個名字涵蓋一個不是 agent reference 的東西;名實不符的成本由未來每個讀者持續支付。

**Alternative considered**:擴大 `agent-reference-layout` 並改名 `okf-bundles`。否決 —— 會把「跨 tool 部署到 `~/.agent`」與「repo-level 不部署的 context」兩件不同的事綁在同一份 spec。

**Alternative considered**:`project-context` 自帶一份 OKF 規則。否決 —— 兩份格式規則必然漂移。

<!-- evergreen-candidate -->
**原則:格式規則與內容規則分屬不同 capability。** 同一份載體格式被兩處以上使用時,格式抽成獨立 spec,內容 spec 引用它。判準是問「換掉格式時要改幾份 spec」——答案若大於一,邊界就切錯了。

### D6:`project-context-doc` 更名為 `project-context`

改名成本已查明為零:非 archive 路徑下該名稱僅出現於其 spec 自身的標題。

`doc` 單數在 5 檔 bundle 下已不準確;`project-context-bundle` 則把格式詞放進內容 capability 的名字,與 D5 剛切乾淨的邊界相衝。`project-context` 只編碼不會變的那一半。

### D7:不搬到 `openspec/config.yaml` 的 `context:` 欄位

上游 CLI 主動建議的路徑,三個理由否決:

- `config.yaml` 在 `.gitignore` 內,搬過去等於從 tracked 變成 per-machine。
- `context:` 是每個 request 自動注入,與「project context 刻意不自動載入、需要時才查」的既有設計相衝。
- gitignored 的欄位沒有 PR review,晉升閘門就失去落點。

### D8:不新增 root `CONTEXT.md`,改在 README 加一行

`context/` 在 root 即可見,轉址檔只是多一個會漂移的維護點。`CONTEXT.md` 是 `mattpocock/skills` 的 repo 慣例,無 spec／schema／版本,不在社群 convention 登記處,不足以支撐一個永久維護點。README 是本 repo 唯一的人類入口,新增 root 目錄卻不在那裡提及等於預設沒人會發現。

<!-- evergreen-candidate -->
**新增詞彙:兩層 context。** machine-level(`~/.agent/reference/`,跨 repo、經 chezmoi 部署)與 repo-level(`context/`,本 repo 專屬、不部署)。兩者格式相同、載入時機相同(需要時主動讀,非自動載入),差別只在作用域。

## Risks / Trade-offs

- **搬移途中內容遺失** → 驗收條件明列「原 88 行的每一段皆對應到新 4 檔之一」,並以 `git mv` 起手保留檔案歷史的可追溯性;review 時逐段對照。
- **9 處引用漏改一處** → 驗收以 `grep -rn 'openspec/project\.md'` 在非 archive 路徑下必須無殘留把關,不靠人工清點。
- **三份 skill body 在使用者機器上仍指舊路徑** → 這三份經 chezmoi 渲染,改 source 不會改機器。需 `chezmoi apply` 才生效,且此為既有工作流程的固定步驟(「先在機器上測,再回寫 source」的反向:source 改完要 apply 回機器驗證)。列入 tasks。
- **`agent-reference-layout` 是三天前才 merge 的 spec,現在就重構** → diff 較大,但抽出的是整段既有需求而非改寫,對照容易;且拖到第三個 bundle 出現才做,成本只會更高。
- **本 change 自己產生的 evergreen candidates 要晉升到哪** → 晉升發生在 sync/archive 階段,那時 `context/` 已存在,直接寫入新位置。無中間狀態問題。

## Migration Plan

單向搬移,無需回滾策略(純文件變更,無執行期行為)。順序:

1. `git mv openspec/project.md context/overview.md` 起手,再逐段拆出其餘檔案 —— 讓 git 能辨識為 rename,history 可追。
2. 建立 `context/index.md` 與其餘 concept 檔,補 frontmatter。
3. 更新 9 處 inbound 引用。
4. spec 變更(抽出、更名、改路徑)。
5. `chezmoi apply` 驗證三份 skill body 在機器上生效。

## 後續 change 候選

本 change 刻意不做、但已確認值得單獨處理的兩件事:

### 1. `context/` 內容精簡

`principles.md` 20 條中部分偏長,有可壓縮處。與搬家分開才能讓 reviewer 分辨「某行消失」是疏漏還是刻意。

### 2. `docs/` 概念段落與 `context/` 的單一真相對齊

**不是**把 `docs/` 搬進 `context/`。已評估否決:`docs/` 的 14 份中 11 份是安裝／設定程序(OKF 語彙的 `Playbook`),讀者是「在機器前要把東西弄起來的人」,與 `context/` 的體裁與讀者皆不同;README 文件表格與大量 inbound 連結亦指向 `docs/`。

真正的問題範圍是 `docs/claude-code.md`(515 行)與 `docs/codex-cli.md`(101 行)中**解釋概念**的段落:arch-review 判準分層、discipline skills、dev-workflow、跨工具 parity 等,同時活在 `context/glossary.md`、`openspec/specs/` 與部署中的 skill body。

證據來自本 change 的實作:同一個事實(arch-review 的判準來源)分別在 `openspec/specs/arch-review/spec.md`、`home/.chezmoitemplates/skills/arch-review.md`、`docs/claude-code.md` 三處被改動,僅靠 `grep` 才確保未漏。

處置方向:概念的單一真相留在 `context/`／`specs/`,`docs/` 保留操作說明並改為一行指路。判準是「改一個事實要動幾個檔」。

<!-- evergreen-candidate -->
**原則:重複的判準是「修改時要同步改幾個檔」,不是「讀起來像不像」。** 同一主題出現在多處是合法的,只要各自回答不同問題(怎麼用／要求什麼／為什麼這樣分);同一個**事實**寫在多處才是病。

## Open Questions

無。grill 階段已收斂,10 條決策與 2 條 non-goals 均經使用者確認;實作期間新增的第 3 條 non-goal(`docs/` 對齊)已評估並記於「後續 change 候選」。
