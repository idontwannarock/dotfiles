## Context

`context/` OKF bundle 於 PR #42 上線,`openspec/specs/` 存可驗收的 WHAT,change 的 `design.md` 存一次性決策。三分法就位後,`docs/` 卻沒有被納入任何內容邊界 —— 它早於這套分工存在,累積了大量「為什麼這樣設計」的段落,其中一部分在 `context/` 或 `specs/` 落地後成了副本。

盤點確認的重複(同一**事實**寫在兩處以上):

| docs 位置 | 另一處權威 |
|---|---|
| `claude-code.md:479` arch-review 標 `disable-model-invocation` 的理由 | `principles.md:15`、`arch-review/spec.md:9` |
| `claude-code.md:414` handoff 的 Claude=command / Codex=skill / 共用 body | `principles.md:15,16` |
| `claude-code.md:450` pickup 只依賴兩個段落、目錄不只放 session state | `glossary.md:32` |
| `claude-code.md:446` 落點在 `~/.agent` 的兩個理由 | `glossary.md:33` |
| `claude-code.md:497` arch-review 永不寫 `context/` | `principles.md:23`、`arch-review/spec.md:16` |
| `claude-code.md:481-486` 兩階段掃描紀律 | `arch-review/spec.md:23-32` |
| `codex-cli.md:34` Codex 無 command 概念、包成 skill、共用 body | `principles.md:15,16`(與 `claude-code.md:414` 三處同義) |
| `codex-cli.md:38` Codex frontmatter 需嚴格 YAML | `principles.md:18`、`arch-review/spec.md:19` |

`codex-cli.md:36` 是這個病最直白的證據:那段話自己寫著「兩邊行為同源,不重複記載」,然後把兩階段掃描與判準來源分層又複述了一遍。

約束:`context/` 受晉升閘門管(只在 sync/archive 寫入、需 shipped 實作背書、須為跨 change 反覆適用);`bootstrap-docs` 以 Scenario 斷言 README 必須有哪些安裝指令;`docs/` 有既有 inbound 連結需維持。

## Goals / Non-Goals

**Goals:**

- 每個判斷依據只有一個權威處,改一次事實只動一個檔
- 判準可機械套用,任何人逐句套都得出同一答案,不需個案判斷或問作者
- 建立 gate,使「把可一般化的判斷依據寫回 `docs/`」在下次 review 時有依據可擋
- 掃描涵蓋完整並可稽核:14 份逐份掃過,判「留」的理由也記錄,不靜默截斷

**Non-Goals:**

- 不搬安裝步驟與故障排除進 `context/`
- 不動 `bootstrap-docs` 的任何 requirement
- 不把「`docs/X.md` 是 capability X 的產物」寫成規則
- 不精簡 `context/principles.md`(另開一輪)
- 不掃 `docs/superpowers/specs/`

## Decisions

### D1. 判準用「同步改檔測試」,三步機械規則

```
1. 這句讀者能照做嗎?
   能 → 操作,留 docs。結束。
2. 不能(是判斷依據)→ 換一個工具/情境還成立嗎?
   不成立(只解釋這一個案例)→ 留 docs。結束。
   成立 → 屬於 context/。往下:
3. principles.md / glossary.md 已有對應條目嗎?
   有 → docs 端刪句,留一行指路;context/ 不動
        (除非該實例揭示既有條目沒涵蓋的面向,才補)
   沒有 → 標 <!-- evergreen-candidate --> 進 design.md,
          由 sync/archive 對照實作決定晉升
```

第 2 步的尺沿用 `glossary.md:34` 判斷 machine-level / repo-level 時的「換一個專案還成立嗎」,不發明新判準。

**實作揭露的修正(task 2.3):** 第 1 步原寫「能照做 → 屬 `docs/`」,但 `docs/codex-cli.md:38`「Codex frontmatter 要嚴格 YAML,`description` 含 `:` 必須加引號」既照做得動、又與 `principles.md:18` 逐字同義 —— 字面套用會把一個確認的重複判成「留」。補上防護:操作步驟屬 `docs/`,**除非**該步驟連同其理由已在 `context/` 有對應條目。並在 spec 明寫根判準(同一事實改變時需同步修改的檔案數為一)以覆蓋任何步驟的誤判,使規則不因未來出現新的邊界案例而失效。

**替代方案一:體裁測試(讀者能不能照做?不能就搬)。** 否決 —— 少了第 2 步的一般化檢查,會把大量一次性理由誤判成該搬。實測:`docs/powershell.md:32`「不自動切換 —— 需 admin、具破壞性、且 pwsh 是 `.ps1` interpreter 的 chicken-and-egg」在體裁測試下該搬,但它只解釋那一支 script 的那一個選擇,背後的一般原則(`principles.md:29` 自動化 gate 在人審)早已在 `context/`。搬它只會把 `principles.md` 灌成流水帳,與下一輪的精簡直接對撞。

**替代方案二:只做第 1 步(純刪重複)。** 否決 —— 只處理已重複的事實,尚未重複的概念留在 `docs/`,`context/` 一長就又變重複。

**關鍵性質:第 3 步的預設是「`context/` 不動」。** 本輪絕大多數動作是 `docs/` 減行,不是 `context/` 增行。這是本設計不會撐大 `principles.md` 的原因。

### D2. 指路粒度為每份檔一行,不做逐處硬連結

被改動的 docs 檔在標題下方加一行指向 `context/`。逐處硬連結(在每個刪句處寫「理由見 `context/principles.md` 的『xxx』」)會產生大量指向條目**標題文字**的引用 —— 下一輪精簡 `principles.md` 一改措辭,這些指路全部漂掉。粒度放在檔案層級,`context/` 只有四份、`principles.md` 只有 23 條,讀者的查找成本本來就低。

### D3. 規則只寫進 `project-context`,不在 `bootstrap-docs` 複製或加 pointer

`bootstrap-docs` 的實際涵蓋範圍比名字窄得多。它誕生於 2026-02-23 的 `migrate-to-chezmoi`(`2ab897f`),原始定義是「README 各平台最小前置安裝說明(git、chezmoi)與完整操作指南」—— README-only 且刻意如此,對應 `capability-map.md:31`「上手」分組的「新機器或新讀者的入口」。6 條 requirement 有 5 條斷言 README;第 6 條末尾的「`docs/powershell.md` SHALL 與此一致」是防止兩處講不同 pwsh 安裝方式的**一致性 rider**,不是納管。

因此在它裡面加一個**單獨的** pointer(暗示它與 `docs/` 治理有關)會製造它管不到的涵蓋錯覺 —— 與直接複製規則是同一個病,只是輕一點。改為修它那句過寬的 Purpose(「定義 README / **docs** 的 bootstrap 文件需涵蓋的內容」),收緊為入口路徑。那一行正是導致誤讀的來源。

實作時的調整:收緊後的 Purpose 末尾保留一句「本 capability 不納管 `docs/` 目錄……`docs/` 的內容邊界見 `project-context`」。這與「不加 pointer」的字面相反,但符合其目的 —— 免責在前、轉址在後的形式消滅誤讀而非製造誤讀,且指的是 capability 名而非規則內文,規則措辭變動時此處不需同步修改。

**替代方案:規則兩份 spec 都寫完整。** 否決 —— 一條規則改一次要動兩份 spec,與本 change 的 Why 自我矛盾,也違反 `principles.md:24`(「換掉格式時要改幾份 spec,答案大於一就是邊界切錯」)。

### D4. `docs/superpowers/specs/` 排除在外

兩份共 55KB 的 corp-ssh 歷史設計文件,性質等同 archived `design.md` —— 記錄的是當時怎麼想,不是現在的權威。對它們套規則等於改寫歷史記錄。

### D5. 驗收採「掃描台帳」而非抽查

第 1 個 task 產出逐份逐句的判定台帳(檔案、行號、判定、依據哪一步、處置),含判「留」的項目。理由:成功判準之一是涵蓋完整,而抽查證明不了完整;台帳同時讓 review 者能驗判準是否被一致套用,而不只驗結果好不好看。台帳落在本 design.md 的附錄,隨 change archive。

<!-- evergreen-candidate -->
**候選:spec 的 Purpose 要精確描述實際涵蓋範圍,過寬的措辭會被當成納管宣告。** `bootstrap-docs` 的 Purpose 寫「README / docs」但 6 條 requirement 有 5 條只斷言 README,導致本輪兩度誤判它是「管 `docs/` 的 spec」。判準:Purpose 提到的每個載體,requirement 裡都應該有對應斷言;沒有的就不該出現在 Purpose。

<!-- evergreen-candidate -->
**候選:需要可發現性時加 pointer,不複製規則。** 同一條規則若寫進兩份 spec,改一次要動兩處 —— 這是 `principles.md:24` 的判準在 spec 之間的形式。可發現性問題用單向指路解決,或修正讓人找錯地方的那句描述。

<!-- evergreen-candidate -->
**候選:`docs/X.md` 是 capability X 的產物,不是獨立載體。** `docs/` 下沒有統一的管轄 spec;文件內容的斷言分散在它所記載的那個 capability 的 spec 裡(`tool-dependencies:517` 斷言 `docs/claude-code.md` 要標明 jdtls 來源;`arch-review` 整份對應 `claude-code.md` 的 Arch Review 章)。本輪僅有兩個實例背書,是否夠格晉升由 sync/archive 裁定。

## Risks / Trade-offs

**「可驗收的規則」與「反覆適用的判斷依據」邊界本身模糊 → ** 兩者可能同時成立:`principles.md:13` 講 `exact_` 的判斷方式與代價,`claude-config` spec 講可驗收的 SHALL NOT,改用 `exact_` 時兩處都要動。緩解:沿用已記錄的分界 ——「同一主題出現在多處合法,同一個**事實**寫在多處才是病」。操作化為:能寫成 SHALL/SHALL NOT 並附 Scenario 的 → `specs/`;「怎麼判斷前提成立」「代價是什麼」→ `context/`。本輪不擴大處理這條既有的輕度重疊。

**刪句讓 docs 的原地讀者失去解釋 → ** 照著 `docs/` 操作的人得跳到 `context/` 才知道為什麼。緩解:第 2 步保證只有**可一般化**的句子被刪,單一案例的理由原地保留;加上 D2 的每檔一行指路。

**14 份逐句掃有判定不一致的風險 → ** 2109 行的量級,前後判準可能漂移。緩解:D5 的台帳把每個判定的依據步驟寫出來,review 時可交叉比對同類句子是否得到同樣判定。

**`codex-cli.md:36` 刪除後可能留下語意斷裂 → ** 該段同時承載「arch-review 是什麼」與「完整說明見 claude-code.md」。緩解:保留指路句,只刪複述的內容摘要;inbound 連結列為成功判準之一。

## 附錄:掃描台帳

14 份逐份掃過,行數合計 2109。判定依三步規則,依據欄標明由哪一步決定。

### 有刪除的檔案(3 份)

| 檔案 | 位置 | 判定依據 | 處置 |
|---|---|---|---|
| `claude-code.md` | L21-23 `exact_` 不適用於可被他人寫入的目錄 + 代價 | 步驟 3(`principles.md:13` 已有,且更完整) | 刪理由,保留「這兩個目錄非 `exact_`」的事實與「退役要進 `.chezmoiremove`」的操作 |
| `claude-code.md` | L89 「只刪安裝行不會傳播移除」 | 步驟 3(`principles.md:11` `run_*` 副作用要顯式反轉) | 刪一般化語句,保留本案機制(`run_update-claude-plugins` 依 `enabledPlugins` 迭代) |
| `claude-code.md` | L171 「適用 user 通常自己打 `/name`、不依賴 model 自動觸發的 skill」 | 步驟 3(`principles.md:15` 能力的部署形狀由觸發模式決定) | 刪判準,保留 budget 機制事實,改指「由判斷依據決定」 |
| `claude-code.md` | L248-251 「腳本互相呼叫一律用絕對路徑」+ PATH interop 理由 | 步驟 3(`principles.md:17` 逐字同義) | 刪理由,保留歷史事實(該 command 已移除及其後果) |
| `claude-code.md` | L414 「Claude 走 command + `disable-model-invocation`;Codex 無 command 概念」 | 步驟 3(`principles.md:15,16`) | 刪部署形狀理由,保留檔案路徑對照 |
| `claude-code.md` | L446 「落點刻意在 `~/.agent`,理由有二:跨工具與跨機器邊界」 | 步驟 3(跨工具部分見 `glossary.md:33`) | 刪理由,保留落點事實與 `.gitignore` 副作用 |
| `claude-code.md` | L450 「pickup 的檔案解析是格式無關的…只對兩個段落有行為依賴」 | 步驟 3(`glossary.md:32` pickup 契約逐字涵蓋) | 刪契約說明,保留「這裡也放 arch-review 報告」的事實 |
| `claude-code.md` | L463-469 能力存在理由 + 與 `code/review-*` 對照表 | 步驟 3(`arch-review/spec.md` Purpose 已承載) | 整段換成指向 spec 的一句 |
| `claude-code.md` | L479-503 `disable-model-invocation` 理由、兩階段掃描、判準來源分層、只診斷不動刀 | 步驟 3(`arch-review/spec.md:9,23-32,38-46` + `principles.md:15,23`) | 刪,保留路徑參數與產出路徑兩項操作 |
| `codex-cli.md` | L34 「Codex 沒有 command 概念,一律包成 skill,共用同一份 body」 | 步驟 3(`principles.md:15,16`;與 `claude-code.md:414` 為三處同義) | 刪理由,保留部署路徑事實 |
| `codex-cli.md` | L36 arch-review 兩階段掃描與判準來源分層摘要 | 步驟 3(該段自承「不重複記載」卻複述) | 刪摘要,只留指路 |
| `codex-cli.md` | L38 「Codex frontmatter 要嚴格 YAML」 | 步驟 1 防護 + 步驟 3(`principles.md:18` 逐字同義) | 刪,由檔頭指路涵蓋 |
| `user-scripts.md` | L5 「腳本必須放 `home/` 之內,否則 alias 失效」 | 步驟 1 防護 + 步驟 3(`glossary.md:12` `.chezmoiroot` 條目連舉例都相同) | 刪理由,保留「新增腳本放哪」的操作 + 指路 |

### 判「留」的檔案(11 份)

| 檔案 | 行數 | 判定依據 |
|---|---|---|
| `corp-ssh-setup.md` | 357 | 步驟 1(安裝程序、troubleshooting 表、`ssh -v` 兩因辨別法)與步驟 2(Kerberos 失敗調查、group membership 說明皆綁定本案)。該檔已自行遵守不複述紀律 |
| `corp-ssh-setup-windows.md` | 321 | 同上。L301-304、L315-318 明白指向 WSL 那份而不複述,是本輪判準的既有實踐 |
| `claude-zai-wrapper.md` | 195 | 步驟 2 —— `## 設計筆記` 四條「為什麼」皆綁定本案(z.ai 的 model tier、PS 對 bash 的語法差異、settings.json 全域性、WSLENV 歷史) |
| `renovate.md` | 130 | 步驟 1(annotation 寫法、datasource 分層、GitHub 一次性設定皆可照做) |
| `ssh.md` | 109 | 步驟 1(全檔為指令與設定範例) |
| `rtk.md` | 96 | 步驟 1 與步驟 2 —— exit code 對照、blacklist 清單為操作;display layer bug 只解釋 RTK 這一個工具 |
| `git-credentials.md` | 83 | 步驟 2 —— `PROGRA~1` 短名、GCM 找 `git.exe` 的位置、WSL 快取 Windows PATH,皆綁定 GCM 這一個案例 |
| `vim.md` | 78 | 步驟 1(安裝、快捷鍵、輸入法切換對照表) |
| `bash.md` | 53 | 步驟 1(平台載入對照、`createnewlog` 行為與前置條件) |
| `powershell.md` | 41 | 步驟 2 —— L32「不自動切換:需 admin、具破壞性、pwsh 是 `.ps1` interpreter 的 chicken-and-egg」只解釋這一支 helper;其一般原則 `principles.md:29` 未被複述 |
| `starship.md` | 13 | 步驟 1(`command_timeout` 調值與 Windows Defender 原因,綁定本案) |

### 掃描期間發現、範圍外的問題(不在本 change 處理)

- **`renovate.md` 自我矛盾。** L5-7 寫「nothing auto-merges」,L84-87 寫 patch/minor/pin 會 auto-merge。auto-merge 是後來加的,開頭那段沒同步更新。屬事實正確性缺陷,非重複,不在本輪判準涵蓋範圍。
- **`principles.md:29` 已與實作漂移。** 該條寫「Renovate / mirror workflow 只開 PR;沒有人審 + 明確 `chezmoi apply` 不落地」,但 low-risk 更新現在由 CI gate 取代人審自動合併。這是同一事實在 `docs/` 與 `context/` 之間漂移 —— 本 change 要治的病最有害的形態。修正方向:`context/` 只保留「自動化不在無把關的情況下落到機器上」的原則,把關機制(人審 vs CI gate)屬本案細節留 `docs/`。依晉升閘門,於 sync/archive 階段修正。

<!-- evergreen-candidate -->
**候選:被學會忽略的 gate 比沒有 gate 更糟。** 出自 `claude-code.md:482`(arch-review 刻意不掛進 dev-workflow / finish-branch)與 L486(硬湊候選的體檢工具跑第二次就沒人信)。它同時消耗注意力又給出虛假的安全感,因此關卡的正確頻率應由訊號密度決定,而非「每次都跑最安全」。`context/` 無對應條目。晉升後 `docs/` 端該段應改為指路。

<!-- evergreen-candidate -->
**候選:祕密放加密 vault,不放明文環境變數。** 出自 `claude-zai-wrapper.md:167-169`。`HKCU\Environment` 與 `~/.bashrc` 的 export 都是明文,任何能讀使用者環境的程式都看得到。兩個 shipped 實例背書(corp-ssh 的 `pass`/`gopass`、claude-zai 的 token)。與 `principles.md:25`(憑證只留本機、不上雲)是不同的軸 —— 那條管「本機 vs 雲端」,這條管「明文 vs 加密」。
