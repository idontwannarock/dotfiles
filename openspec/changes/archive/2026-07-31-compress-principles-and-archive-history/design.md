## Context

PR #44 建立了四分法內容邊界與三步判定規則,並在掃描期間記下三件範圍外的問題。本 change 處理它們。

三件事共用一個主題:**讓每份文件只承載它該承載的東西**。`principles.md` 混了原則與會過期的狀態報告;`renovate.md` 混了兩個年代的敘述;`docs/` 混了現行文件與凍結歷史。

## Goals / Non-Goals

**Goals:**

- `principles.md` 可導航(分組)且無自我違反的斷言,語意一條不減
- `renovate.md` 開頭與內文對同一件事說同一句話
- `docs/` 只剩現行文件;凍結記錄與其他歷史放在一起
- 歸檔不編造當時不存在的 artifact

**Non-Goals:**

- 不改 `principles.md` 任何一條的**判斷結論**,只改它的組織與措辭
- 不逐條修 `docs/superpowers/` 內嵌草稿裡的失效連結
- 不為 corp-ssh 或 wezterm 補寫 capability spec
- 不動 `docs/` 其他 12 份(PR #44 已逐句掃過)

## Decisions

### D1. 分組用 `##` 小標題,不拆檔

`principles.md` 25 條平鋪,讀者只能線性掃。分五組加 `##` 小標題:chezmoi 機制、跨平台與跨工具、規範與文件寫法、祕密與把關、機器狀態。

**替代方案:拆成多個 concept 檔**(`principles-chezmoi.md` 等)。否決 —— `project-context` spec 要求「依知識性質分檔」,而「反覆適用的原則」本身就是一種性質;再依主題拆下去,讀者得先猜該讀哪一份,而分組小標題用零成本達到同樣的導航效果。`okf-bundle-conventions` 也明文說「主題 SHALL NOT 用作 `type`,主題已由目錄結構與檔名表達」——同一個道理適用於檔案切分。

### D2. 只合併「條目自己宣告同源」的三組

合併對象不靠我判斷相似度,靠條目自己寫的話:

| 組 | 自承同源的原文 |
|---|---|
| metadata 只表達非預設 + 分類欄位不該每檔一值 | 「這與上一條是同一個病的兩種症狀」 |
| 憑證只留本機 + 祕密放加密 vault | 「這與上一條是不同的軸」 |
| `run_*` 副作用要顯式反轉 + `exact_` 只用於獨佔目錄 | 「與 `run_*` 副作用是同一類陷阱」 |

第三組的共同核心是**移除不會自動傳播**:chezmoi 的收斂只涵蓋它 declare 的東西,刪 source 只停止新機器安裝,已 apply 的機器永久保留。兩個具體形態(腳本裝出來的副作用、非 `exact_` 目錄下的檔案)與兩個對策(冪等反安裝、`.chezmoiremove` 點名)收在同一條之下。

**不合併**「Windows toolchain 脫離 Scoop」與「Windows PATH 要 SSH-safe」——同為 Windows 但一個管 provisioning 來源、一個管 PATH 形狀,合併會產生一條沒有單一判準的條目。**不合併**三條談 spec 寫法的(可機械套用的規則、格式/內容分屬不同 capability、Purpose 要精確)——它們判準不同,靠分組相鄰即可,合併會損語意。

### D3. 刪除會過期的斷言與操作指令

`principles.md:21` 定的規則反過來套用在它自己身上:

| 位置 | 原文 | 處置 |
|---|---|---|
| L15 | 「既有實作已在遵循這條分界(…vs **六個** discipline skills)」 | 刪數量與狀態報告。skill 增減即 drift,且「既有實作已在遵循」是當下狀態不是原則 |
| L25 | 「`bootstrap-docs` 的 Purpose 曾寫「README / docs」但 **6 條 requirement 有 5 條**只斷言 README」 | 保留案例,刪數字 |
| L16 | 「**Gemini CLI 已放棄,不要去檢查它。**」 | 刪。這是操作指令與當下狀態,不是反覆適用的原則;目標工具清單本身也會變 |

### D4. 歸檔:三個 change 目錄,缺的 artifact 不補

| 來源 | 去處 | 檔名 |
|---|---|---|
| `specs/2026-04-24-corp-ssh-redesign.md` | `archive/2026-04-24-corp-ssh-redesign/` | `design.md` |
| `specs/2026-04-30-corp-ssh-windows-phase2-design.md` | `archive/2026-04-30-corp-ssh-windows-phase2/` | `design.md` |
| `plans/2026-04-30-corp-ssh-windows-phase2.md` | 同上 | `tasks.md` |
| `plans/2026-04-21-wezterm-migration.md` | `archive/2026-04-21-wezterm-migration/` | `tasks.md` |

**不補 `proposal.md` 與 `specs/` delta**:這三個 change 從未有過它們(當時流程尚未存在,corp-ssh 至今也無 capability spec)。反推寫出來的話,archive 就不再能假設「每一份都是當時真的寫過的東西」——那是它唯一的價值。

**不放 `.openspec.yaml`**:它記錄的是所用的 schema,而這三個 change 沒有用任何 OpenSpec schema。填一個假值比留空更糟。

**出處說明只寫一份**,放 `openspec/changes/archive/README.md`,不在三個目錄各寫一次 —— 這正是 PR #44 立的規則。

用 `git mv` 搬移,讓 git 認得 rename,history 可追。

### D5. `openspec` CLI 不受影響(已驗證)

`openspec list` 只回報 active change(archive 下 50+ 個既有目錄都不出現);`openspec validate --all` 的 30 項全是 `openspec/specs/` 下的 main spec。archive 對兩者皆為惰性,因此形狀不完整的目錄不會讓任何命令失敗。實作時仍會再跑一次確認。

## Risks / Trade-offs

**合併後單條變長,可能反而更難讀 → ** 三組合併各自把 2 條變 1 條,但內容不刪,單條長度接近加總。緩解:合併時把兩條共有的前提抽到條首一句,具體形態縮為並列子句;若某組合併後長度超過原本兩條之和,視為合併失敗,回退為分開兩條並靠分組相鄰表達關聯。

**「語意不減」難以機械驗證 → ** 這是本 change 最主要的風險。緩解:實作時逐條對照 `git show HEAD:context/principles.md`,產出一張「原 25 條 → 新條目」的對照表放進 design.md 附錄,每條標明「保留 / 併入哪條 / 刪除及理由」。review 時對照表本身就是驗收依據,不必重讀全文比對。

**歸檔後 `docs/` 的兩條 inbound 連結變長且跨目錄 → ** `../openspec/changes/archive/<name>/design.md` 比原本的 `superpowers/specs/<file>.md` 難讀。接受:代價換到的是 `docs/` 內容一致,且連結仍可解析、仍受連結檢查涵蓋。

**archive 目錄形狀不一致,未來工具若開始驗 archive 會踩到 → ** 目前 CLI 惰性,但 OpenSpec 是外部依賴,未來版本可能新增 archive 驗證。緩解:`README.md` 明說這三個目錄是 pre-OpenSpec 記錄;真出問題時把它們移到 archive 之外即可,搬移成本低。

## 實作揭露的三處偏離

**(a) `renovate.md` 的矛盾有 3 處,不是 1 處。** task 1.2 的全檔複讀另外抓到 L72(「三個 mirror pin…nothing auto-merges」,與 L95-97 的「Mirror PRs too…enables squash auto-merge」相反)與 L125(「review + merge」暗示一律人審)。這正是 `principles.md` 那條推論預測的:「修掉一個這類斷言時要把同份文件全掃一遍,同類實例不會因為只有一個被指出就只有一個存在。」

**(b) `run_*` 副作用 + `exact_` 那組不合併,改為消除重複的前提。** D2 預測它們該併,但實際重疊的只有**前提**(「刪 source 只停止新機器安裝,已 apply 的機器永久保留」)—— 兩條各寫了一次。真正的缺陷是那個前提被寫兩遍,不是兩條該變一條:合併後的單條會同時承載「移除的傳播」與「`exact_` 的語意與判斷方式」兩個不同判準。依 D2 的回退規則,改為前提只寫在第一條,`exact_` 那條專講它自己的語意,靠分組相鄰表達關聯。**條數不減,但重複消除。**

**(c) 分組是四組不是五組,且範圍多一個檔案。** 原規劃的「機器狀態」組只有一個成員 —— 依 `okf-bundle-conventions` 自己的判準(「只會有單一成員的值不是分類,是換了位置的檔名」),單成員分組不該存在。「有些機器狀態刻意不在 repo 裡」併入「Source 與機器狀態」組,它本來就是「repo ≠ live config」的延伸。

另外,`principles.md` 的跨工具 parity 條目裡有「目標工具 = Claude + Codex」「Gemini CLI 已放棄」—— 前者與 `glossary.md:31` 的 cross-tool 條目**逐字重複**,後者是現況而非原則。依四分法,工具清單屬 domain 詞彙。因此把目標工具的現況(含 Gemini 已放棄)收進 `glossary.md`,`principles.md` 只留「shared body + 薄指標」這個判斷依據。範圍因此多動 `context/glossary.md` 一個檔。

## 附錄:原 25 條 → 新條目對照表

分組:**A** = Source 與機器狀態、**B** = 跨平台與跨工具部署、**C** = 規範與文件寫法、**D** = 祕密與把關。

| # | 原條目(首句) | 處置 | 去處 |
|---|---|---|---|
| 1 | Repo 是 source of truth,不是 live config | 保留,原文不動 | A |
| 2 | 先在機器上測,再回寫 source | 保留,原文不動 | A |
| 3 | `run_*` 腳本的副作用要顯式反轉 | 改寫為「移除不會自動傳播」,吸收 #5 的「代價是自動修剪不會發生」半句 | A |
| 4 | `run_*` 腳本要能從 apply 輸出被讀懂 | 保留,原文不動 | A |
| 5 | `exact_` 只用於 chezmoi 獨佔的目錄 | 保留語意;刪去與 #3 重複的前提(刪 source 只停止新機器安裝),只留 `exact_` 語意與 `comm -13` 判斷方式 | A |
| 6 | 盡量跨平台 | 保留,原文不動 | B |
| 7 | 能力的部署形狀由觸發模式決定 | 保留判準;刪尾句的狀態報告與「六個 discipline skills」數量斷言,改為不帶清單的舉例 | B |
| 8 | 跨工具 parity = shared body + 薄指標 | 保留判準;目標工具清單與「Gemini 已放棄」移入 `glossary.md`(現況屬詞彙) | B |
| 9 | WSL 下呼叫腳本一律用絕對路徑 | 保留,原文不動 | B |
| 10 | Codex frontmatter 要嚴格 YAML | 保留,原文不動 | B |
| 11 | metadata 只表達「非預設狀態」 | **併入**新條目「metadata 只表達非預設,分類欄位要真的能分類」 | C |
| 12 | 一個分類欄位若每個新檔都想新增一個值… | **併入** #11(原文自承「與上一條是同一個病的兩種症狀」) | C |
| 13 | 規範要寫成可機械套用的規則 | 保留,原文不動 | C |
| 14 | `index.md` 只放目錄清單,不放知識本身 | 保留,原文不動 | C |
| 15 | 長青文件只在 sync/archive 階段寫入 | 保留,原文不動 | C |
| 16 | 格式規則與內容規則分屬不同 capability | 保留,原文不動 | C |
| 17 | spec 的 `## Purpose` 要精確描述實際涵蓋範圍 | 保留判準;刪「6 條 requirement 有 5 條」數字斷言與「差點把規則寫錯地方」敘事 | C |
| 18 | 憑證只留本機、不上雲 | **併入**新條目「祕密只留本機,且要加密」的「本機 vs 雲端」軸 | D |
| 19 | 祕密放加密 vault,不放明文環境變數 | **併入** #18(原文自承「與上一條是不同的軸」) | D |
| 20 | 被學會忽略的 gate 比沒有 gate 更糟 | 保留,原文不動 | D |
| 21 | 文件要 model-agnostic、人可讀 | 保留,原文不動 | C |
| 22 | Windows toolchain 脫離 Scoop | 保留,原文不動 | B |
| 23 | Windows PATH 要 SSH-safe | 保留,原文不動 | B |
| 24 | 自動化不在無把關的情況下落到機器上 | 保留,原文不動 | D |
| 25 | 有些機器狀態刻意不在 repo 裡 | 保留,原文不動 | A |

**結果:25 → 23 條**(兩組合併各減 1;`run_*`／`exact_` 那組依偏離 (b) 不減條數,只消除重複前提)。**無任何條目被整條刪除** —— 三處刪除都是條目內的數量斷言、狀態報告或敘事贅語,判斷結論一條未動。
