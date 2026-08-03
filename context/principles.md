---
type: Principle
title: 反覆適用的原則與約束
description: "跨 change 反覆適用的長青判斷依據,分四組:source 與機器狀態、跨平台與跨工具部署、規範與文件寫法、祕密與把關。"
---

# 反覆適用的原則與約束

## Source 與機器狀態

- **Repo 是 source of truth,不是 live config。** 兩邊不自動互通。
- **先在機器上測,再回寫 source。** 固定四步:改機器上實際設定 → 確認運作 → 回寫 chezmoi source → 更新文件。(尚在「local-test-only」的項目都卡在這條沒走完。)
- **有些機器狀態刻意不在 repo 裡。** 例:全域 `git core.hooksPath` 分派器、corp GitLab 實例的 FQDN(`HKCU\Environment` + WSLENV)、corp-ssh 金鑰的單一實體磁碟備份。這是「為什麼這個沒被重現」類驚訝的固定來源——需求分析時要記得 repo ≠ 機器全貌。
- **移除不會自動傳播。** chezmoi 的宣告式收斂只涵蓋它 declare 的檔案:刪掉 source 檔只會停止新機器安裝,已 apply 過的機器永久保留。三個常見形態 —— 腳本裝出來的東西(套件、plugin 註冊、外部 CLI 設定)本來就不在收斂內,退役時要補一段冪等的反安裝;非 `exact_` 目錄下的檔案不會被修剪,退役時要在 `.chezmoiremove` 點名路徑;`modify_*` 寫進目標檔的欄位是 **patch 而非 render**,停止寫入只會讓舊值原地留存,退役時要主動 `del`,且刪除必須是外科式的(只濾掉目標那一條,不整體覆寫 key——同一個 key 常有其他工具在 runtime 寫入的條目)。同理,任何「本機手動跑一次」的收尾都不會傳播。

  三者可能同時發生在同一次退役上,漏掉任一個都會留下互相矛盾的殘骸:只刪 script 會留下指向不存在檔案的註冊,只刪註冊會留下孤兒 script。
- **`exact_` 只用於 chezmoi 獨佔的目錄。** 它宣告「此目錄的內容完全屬於 chezmoi」,apply 會刪除其中所有未被管理的檔案。凡是可能被 plugin、其他工具或使用者手動寫入的目錄(`~/.claude/commands/`、`~/.claude/skills/`),套用它就是靜默刪檔。判斷方式很直接:`comm -13 <(chezmoi managed 的清單) <(實際檔案清單)` 若非空,前提就不成立。
- **以 repo 為單位的 agent 產物,repo 身分只有一個定義:`slug(dirname(realpath(git-common-dir)))`。** auto-memory、handoff 與未來同類產物都套這條,兩個系統才會對「同一個 repo」得出同一個答案。不要用 `git rev-parse --show-toplevel` —— normal 佈局下兩者相同,bare+worktree 下它回傳當前 worktree,於是同一個 repo 的產物依 worktree 各自落在不同目錄、互相看不見。這個 bug 不會報錯:寫得出來、找得到、只是找不到*別的 worktree 寫的那些*,要等到有人在另一個 worktree 撈不到東西才會浮現(`shoalter-ai-toolkit` 曾因此分裂成三個 handoff 目錄)。
- **`run_*` 腳本要能從 apply 輸出被讀懂。** 每支有起訖 banner(結束的標題取自開始時記下的那一份,不另外手寫,否則必然漂移),每個段落印出**目的**而非代號,早退與失敗也要收尾。同一 interpreter 內重複兩次以上的邏輯抽到 `.chezmoitemplates/scripts/`;若多支腳本抽掉資料後控制流逐字相同,合併成一支資料表驅動的腳本。細節在 `chezmoi-author` skill。
- **會讀自己輸出的腳本必須是不動點。** `modify_*`(以及在 Windows 代其職責的 `run_after_*` shim)吃的是目標檔上一輪的內容,所以 `f(f(x))` 必須等於 `f(x)`。這與安裝腳本「已裝就跳過」的冪等是不同性質:那個靠守衛,這個靠輸出形狀與輸入中不具語意的部分無關。破口幾乎都在**接縫** —— 從舊檔切一段保留、再接上新內容時,分隔用的空白必須由單一方提供,被保留的段落不得自帶尾端空白,否則每輪疊加一次而 TOML/JSON 這類格式又對它無感,於是沒人發現,只有 `chezmoi diff` 永遠不乾淨。驗收只看一件事:修好之後**不需要手動清理現場**;若還得清一次,修的就是症狀而不是成因。

## 跨平台與跨工具部署

- **盡量跨平台。** 目標是 Windows/macOS/Linux 皆可用;平台差異用 per-platform 片段拆分,而非整份分叉。
- **可逆性而非副作用決定 gate 的位置。** 一個能力該不該讓模型自行啟動,問的是「做錯了救不救得回來、外面看不看得到」——**不可逆或外部可見**才鎖(Claude command + `disable-model-invocation: true`),兩者皆非則放行。本地檔案與 git 物件可救(`.git` 還在,commit/rebase 都能靠 reflog 回復);遠端寫入與外部通知不可救(Issue comment 刪掉也已被看過,workflow 跑了就是跑了)。**不要用「有副作用」當判準**:它對 `git commit` 與「寫 GitHub Issue comment」給出相同答案,而兩者風險差一個量級;判準一旦失去鑑別力,實際分類就會靠直覺,於是同類能力散落在閘門兩側(舊判準下 `git/clean-gone` 刪本地分支卻沒鎖,唯讀的 `code/review-types` 反而鎖著)。

  兩個推論。其一,**flag 擋的是自動啟動,不是能力** —— 模型讀得到 `~/.claude/commands/<name>.md` 的規格,鎖住只會換來它繞路自己實作一份沒有護欄的版本(`git-commit` 的價值正是敏感檔阻擋清單與禁止 `git add -A`,鎖住它等於逼模型走無護欄的預設路徑,對公開 repo 而言方向是反的)。其二,**token 成本不歸這條判準管** —— 整庫掃描很貴但可逆,控制頻率的責任在 skill body 的觸發條件,不在 wrapper 的 flag。
- **部署形狀:Claude 端 command、Codex 端 skill。** Claude 端走 command 換得穩定的 `/name` 入口與較省的 system prompt budget;Codex 無 command 概念,同一份 body 包成 skill。這是形狀差異,與可呼叫性無關 —— 可呼叫性由上一條的判準決定。Codex 沒有 gate 欄位,所以仍需鎖住的能力在那邊留有無法消除的落差;**不要用 description 措辭去補**,那會造成已施加限制的錯覺而實際約束力無法驗證。
- **跨工具 parity = shared body + 薄指標。** 權威 body 一份在 `~/.agent` / `.chezmoitemplates`,每工具一個 name-map wrapper。目標工具清單見詞彙表。
- **WSL 下呼叫腳本一律用絕對路徑。** PATH interop 把 Windows 家目錄的 `~/.local/bin` 併進 WSL 的 PATH,所以 bare 名稱可能命中另一台機器、另一個年代的同名腳本。腳本正典搬家後,舊位置的副本要用 `.chezmoiremove` 點名清掉 —— 留著它就是留一條會靜默跑到舊碼的路徑。
- **Codex frontmatter 要嚴格 YAML。** skill `description:` 若含 `:`/`#`/開頭 `[`{` 必須加引號;Claude 容忍、Codex 會報錯。用真的 YAML parser 驗,不要只 grep。
- **Windows toolchain 脫離 Scoop。** Go/JDK/GnuPG 等從官方第一手來源經 `.chezmoiexternal.toml` / 官方安裝器 provision,搭配一次性 `run_once_after_migrate-scoop-*` 清理。
- **Windows PATH 要 SSH-safe。** Win32-OpenSSH 不展開 PATH 裡的 `%JAVA_HOME%`;用 wrapper `.cmd` shim,別把原始 JDK bin 放進 PATH。

## 規範與文件寫法

- **規範要寫成可機械套用的規則,不是個案判斷。** 「列出三個子目錄」、「四檔存在」、「僅含一句話摘要」這類斷言把當下的檔案樹凍結成需求,目錄一增減就 drift,而且遇到新案例時沒人知道該怎麼套。改寫成規則(「有 `index.md` 的目錄連目錄,沒有的連檔案」)才同時涵蓋現況與未來,且任何人都能得出同一個答案而不必問作者。**推論:修掉一個這類斷言時,要把同份 spec 全掃一遍** —— 同類實例不會因為只有一個被指出就只有一個存在。
- **metadata 只表達「非預設狀態」,而分類欄位要真的能分類。** 兩者是同一個病的兩種症狀:前者稀釋訊號,後者消滅訊號。有預設值的欄位就省略;沒有預設值的欄位,「不存在」本身即明確語意(OKF 的 `status` 缺省即 `stable`,不必寫;`stale_after` 無預設值,不寫即代表長青),全檔一律填同一個值等於把訊號稀釋成噪音。反過來,一個分類欄位若「每個新檔都想新增一個值」,它就不是分類欄位,而是換了位置的檔名 —— 判準是問「這個值會不會有第二個成員」,舉不出第二個成員就不該新增。同理,主題不該當分類值:主題已由目錄結構與檔名表達。
- **格式規則與內容規則分屬不同 capability。** 同一份載體格式被兩處以上使用時,格式抽成獨立 spec,內容 spec 引用它;內容 capability 的名字也不該編碼格式(`project-context` 而非 `project-context-bundle`)。判準是問「換掉格式時要改幾份 spec」——答案若大於一,邊界就切錯了。**同一條規則也不該寫進兩份 spec**:規則寫一處,別處只放單向指路。可發現性的問題用指路解決,或修正那句讓人找錯地方的描述,不用複製。
- **spec 的 `## Purpose` 要精確描述實際涵蓋範圍。** 過寬的措辭會被讀成納管宣告,而 requirement 才是真正的邊界。判準:Purpose 提到的每個載體,requirement 裡都要有對應斷言;沒有的就不該出現在 Purpose。`bootstrap-docs` 的 Purpose 曾寫「README / docs」,但它的 requirement 幾乎只斷言 README,結果兩度被誤判成「管 `docs/` 的 spec」。
- **`index.md` 只放「這個目錄有什麼、何時讀哪個」,不放知識本身。** 任何一段內容若會被 agent 當答案引用,它就屬於一個具名檔案。這條界線讓 index 永遠可被自動生成或重建;OKF 更是把 `index.md` 列為 reserved filename,明文禁止當 concept 用。
- **長青文件只在 sync/archive 階段寫入。** `context/` 的每一條都要有已 ship 的實作背書,所以 grill、arch-review、實作階段一律只把候選標記進 `design.md`,由 sync/archive 對照實際做出來的東西再決定晉升。閘門管的是**證據等級**而非正確性 —— 一條還沒被實作驗證過的原則即使是對的,也先留在 `design.md`;否則這份文件會慢慢變成「我們覺得應該這樣」的清單,而它的價值恰恰在於每一行都指得出對應的實作。
- **文件要 model-agnostic、人可讀。** reference body 放 tool-neutral 位置;專案文件描述意圖,不綁單一工具的實作。

## 祕密與把關

- **祕密只留本機,且要加密。** 兩個軸。**本機 vs 雲端**:corp-ssh、local-files 的祕密都在本機磁碟或使用者腦中,雲端密碼管理器(cloud Bitwarden)明確排除,因為情境是單機、無跨機同步需求。**明文 vs 加密**:`HKCU\Environment` 與 `~/.bashrc` 的 export 都是明文,任何能讀使用者環境的程式都看得到,所以走 GPG 加密的 vault、gpg-agent 短期 unlock;代價是 agent 沒 warm 時要打一次 passphrase、跨機器要複製 encrypted blob。已套用於 corp-ssh(`pass`/`gopass`)、claude-zai token 與 corp GitLab token。
- **祕密與 corp 識別資訊是兩個問題,答案不同。** 祕密進本機加密 vault;corp 識別資訊(實例 FQDN、內部主機名)留在 OS 的機器本地狀態(`HKCU\Environment`、機器本地的 `~/.ssh/config`)。兩者都不進 repo,但混為一談會導致把 FQDN 塞進 `pass` —— 在那裡它既不好找又不合用,因為它根本不是祕密,只是不該公開。本 repo 為公開 repo,「零 corp 主機名」是可機械驗證的硬邊界:全文搜尋 corp 網域,命中必須為零。
- **自動化不在無把關的情況下落到機器上。** 把關形式可以是人審或自動驗證,但不得沒有 —— Renovate / mirror workflow 只開 PR,低風險更新由 CI gate 放行、`major` 仍需人審。無論哪一種,最後都還要一次明確的 `chezmoi apply` 才會改到機器。把關機制的細節屬各案文件,不寫在這裡。
- **不可回復的操作要問「誤判時損失什麼」,不是「正確時損失什麼」。** 「內容已經備份在別處」不足以支持 `rm` —— 它只證明*判斷正確時*沒有損失,而風險全在判斷錯誤的那些。當保守選項的代價是可忽略的雜訊(多一層永遠不看的 `archive/` 目錄)、激進選項的代價是不可回復的資料消失時,選保守。版控之外的路徑(`~/.agent/`、`~/.claude/`)沒有 undo,這條在那裡尤其硬。2026-08-03 一個 session 拿 slug 字面相似度判定 5 份 handoff 已完成並當場 `rm`,其中 2 份根本沒開始做。
- **被學會忽略的 gate 比沒有 gate 更糟。** 它同時消耗注意力又給出虛假的安全感。所以關卡的頻率由訊號密度決定,不是「每次都跑最安全」——`arch-review` 因此刻意不掛進 `dev-workflow` 或 `finish-branch`,正確頻率是里程碑或數個 change 之後。同理,會硬湊結果的檢查工具跑第二次就沒人信;誠實的「無發現」報告價值在於它排除了疑慮。
