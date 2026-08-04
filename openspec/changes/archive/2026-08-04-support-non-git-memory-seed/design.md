## Context

`claude-memory-seed` 目前有兩個觸發點(`SessionStart` hook、全域 `post-checkout` hook)共用
同一支 script。`SessionStart` 在非 git 目錄照樣會觸發,但 script 第 43 行
`[ -n "$toplevel" ] || return 0` 把非 git cwd 擋掉,所以那些目錄的記憶至今仍留在 Claude 私有
的 `~/.claude/projects/<id>/memory/`。

現行 script 有兩個獨立的路徑概念,目前恰好都由 git 提供:

| 概念 | 現行來源 | 用途 |
|------|---------|------|
| **id 錨點** | `dirname(realpath(git-common-dir))` | 決定 `<id>`,同 repo 所有 worktree 收斂到同一值 |
| **設定落點** | `git rev-parse --show-toplevel` | 決定 `.claude/settings.local.json` 寫在哪 |

這兩者對一般 repo 相同,但對 **worktree 刻意不同**——每個 worktree 各有自己的
`settings.local.json`,內容都指向同一個共享 `<id>`。任何改動都必須保住這個不對稱。

約束:script 是 POSIX `sh`(`set -eu`)、跨 Windows/macOS/Linux、由 hook 呼叫故**絕不可
阻斷 caller**、`jq` 缺席時安靜 no-op。

## Goals / Non-Goals

**Goals:**

- 非 git 專案目錄也能把 auto-memory 種到 `~/.claude/memory/<id>`,達成 model agnostic 的
  共享路徑目標。
- 既有 git repo 行為(含 worktree 收斂、覆寫政策、idempotency)**逐位元不變**。
- 既有 18 個 `~/.claude/memory/<id>` 目錄命名**一字不改**。
- 補上這支 script 從未有過的自動化測試覆蓋。

**Non-Goals:**

- **不寫 `backfill` 子命令**。slug 不可逆(`-a-b-c` 無法還原成 `b/c` 或 `b-c`),要正確反解
  得對每個候選路徑做存在性試探。既有只有 4 個目錄、40 個檔,懶遷移期間記憶不會遺失。
- **不動 `localfiles`**。它雖共用同一套 `<id>` 推導,但功能綁在 `post-checkout` 的 restore
  事件上;非 git 目錄沒有 checkout 事件,擴大適用範圍沒有意義。
- **不改 slug 規則**。`tr '/' '-'` 維持原樣;下面 D4 只影響「查找遷移來源」,不影響任何
  寫出去的目錄名。
- 不處理非 git 目錄的「子目錄收斂」——見 R4。

## Decisions

### D1. 拆開 id 錨點與設定落點,而非讓 `root` 一肩挑

<!-- evergreen-candidate -->
最容易寫錯的改法是把 `toplevel` 直接換成 `root` 一路用到底。那會讓每個 worktree 的
`settings.local.json` 都改寫到主 checkout,破壞現行「各 worktree 自帶設定、共享 id」的設計。

改為明確兩個變數:

| 變數 | git repo | 非 git |
|------|---------|--------|
| `id_root` | `canonical_root()`(不變) | `${CLAUDE_PROJECT_DIR:-$PWD}` |
| `settings_root` | `$toplevel`(不變) | `${CLAUDE_PROJECT_DIR:-$PWD}` |

git 路徑兩個值的來源都與現行完全相同 → 行為零變動。非 git 沒有 worktree 概念,兩者同源。

**Alternative considered**:單一 `root` 變數 —— 拒絕,會靜默破壞 worktree 行為,而且是那種
測試不寫就抓不到的迴歸。

### D2. 非 git 錨點用 `${CLAUDE_PROJECT_DIR:-$PWD}`,且做 `cd -P` 正規化

`CLAUDE_PROJECT_DIR` 是 Claude 對「專案根」的定義,與它 `projects/<id>` 的分桶一致;未設時
fallback `$PWD`(hook 的 cwd 本就是專案目錄),兩條路都安全,所以不需要事先驗證該變數在
`SessionStart` 是否必定存在。

取得後一律過 `CDPATH= cd -- "$x" && pwd -P` 正規化,與 `canonical_root()` 現行做法一致——
否則 symlink 過來的專案目錄會拿到 logical path,和 Claude 記的 physical path 分到不同桶。

**Alternative considered**:往上找 marker 檔(`package.json` / `compose.yml` / …)決定專案根
—— 拒絕。那是憑空猜測,而且會跟 Claude 自己的分桶對不上,等於在同一台機器上養出第二套 id 規則。

### D3. 三道寫入護欄,統一套用在解析後的 `settings_root`

拒絕寫入的條件(任一成立即安靜 return 0):

1. `settings_root` = `$HOME`
2. `settings_root` = `/`
3. `settings_root` 位於 `/tmp/` 之下

第 1 條是**硬需求**而非防禦性冗餘:此時設定路徑會落在 `~/.claude/settings.local.json`,
那是 Claude 的 **user-level** 設定檔;寫進去等於把 `autoMemoryDirectory` 全域綁死到單一
目錄,所有專案記憶混成一桶。這是本次改動唯一真正會造成資料損害的失敗模式,而且**不是假想的**
——`/tmp/claude-1000/-home-howardwang/` 底下有 2 個 session 目錄(2026-07-30),證明機器上
確實從 `$HOME` 開過 session。

第 3 條擋 scratchpad 污染——`~/.claude/projects/` 目前已有 2 個
`-tmp-claude-1000--home-...-scratchpad-*` 桶,開放非 git 後每個 scratchpad session 都會生出
一份 `.claude/settings.local.json` 和一個超長 slug 的記憶目錄。

護欄**統一套用**,不分 git 與否。理由是一致性與安全對稱:`$HOME` 若本身是 git repo
(yadm/homeshick 這類佈局)會踩到完全相同的地雷,只擋非 git 等於留半個洞。代價是「`/tmp` 下的
git repo 不再被種子」——見 R2。

**Alternative considered**:只在非 git 路徑套護欄 —— 拒絕,`$HOME` 那條在 git 佈局下同樣致命。

### D4. 遷移來源改「正規化比對掃描」,不再字串拼接

現行 `"$HOME/.claude/projects/$id/memory"` 用**我們的** id 去猜 Claude 的目錄名。實測兩套
編碼在 `_` 上分岔:

```
/home/howardwang/ws/hktv/tw/cashback/cashback_api
  Claude:  projects/-home-howardwang-ws-hktv-tw-cashback-cashback-api/
  我們:    memory/  -home-howardwang-ws-hktv-tw-cashback-cashback_api/
```

改為:掃 `~/.claude/projects/*/`,把候選 basename 與 `$id` 兩邊的 `[-_.]` 一律壓成 `-`
後比對,第一個 `memory/` 非空者勝出。

刻意**不去實作 Claude 的完整編碼規則**——`.` 如何處理沒有樣本可驗,寫死等於再猜一次。
正規化比對是規則無關的:未來 Claude 若新增轉換字元,只要落在 `[-_.]` 就自動涵蓋。

`~/.claude/projects` 不存在時 glob 不展開會留下字面路徑,靠迴圈內的 `[ -d ]` 過濾,不能
依賴 `nullglob`(POSIX `sh` 沒有)。

**Alternative considered**:硬編 `tr '/_' '--'` 產生第二個候選字串 —— 較省事,但只覆蓋
已觀察到的 `_`,`.` 仍會 miss,等於把已知邊角留著。

### D5. 既有 4 個目錄採懶遷移

改動 ship 後,下次在該目錄開 session 由 `SessionStart` hook 自行搬移。遷移的既有前置條件
(目標不存在或為空才搬)已保證不會覆蓋,懶遷移只是延後,不會遺失。理由見 Non-Goals。

### D6. 測試:手捲 POSIX `sh` runner,新增 ubuntu-latest job

`tests/` 現有三支都是 Pester 5、跑在 `windows-latest`。本 script 是 POSIX `sh`,而
`test-pester.yml` 的 `paths` 已經包含 `home/dot_local/bin/**`——測試位置早就預留好了,只是
一直沒人寫。

作法:新增 `tests/claude-memory-seed.test.sh`,黑箱地用 `sh <script> apply|where` 驅動,
把 `HOME` 指到臨時目錄以隔離真實記憶。CI 加一個 `ubuntu-latest` job 跑同一道指令
(`sh tests/claude-memory-seed.test.sh`),不動現有 Windows job。

選 ubuntu 而非在 windows-latest 上借 git-bash,是因為本 script 在 `jq` 缺席時會**安靜
no-op**——若 runner 沒有 jq,測試會全部「通過」但什麼都沒驗到,是最糟的假綠燈。ubuntu-latest
原生有 `sh` 與 `jq`。測試仍 SHALL 顯式斷言 `jq` 可用,讓缺工具時直接紅燈而非假綠。

**Alternative considered**:Pester(與 repo 現有測試一致)—— **實作時實測後否決**。開發機
(WSL)沒有原生 `pwsh`/`powershell`,只有 Windows 側 `pwsh.exe`(Pester 6.0.1,CI 釘的是
5.5)。走 Windows interop 意味著 Pester 6 + git-bash + `\\wsl$` UNC 路徑,三個變數都與
ubuntu CI 不同,本地綠燈不代表 CI 綠燈——等於**沒有可靠的本地紅綠迴路**,每改一行都要 push
才知道結果。測 POSIX `sh` 就用 `sh` 測,本地與 CI 跑的是同一個 shell、同一個 `jq`、同一套
檔案系統語意。現有三支 Pester 測的是 PowerShell 產物,維持不動——工具選擇跟著被測物走,
而非跟著 repo 慣例走。

**Alternative considered**:bats/shunit2 —— 拒絕。手捲 assertion 對這個規模已經夠用,且
**零安裝步驟**;引入框架反而要多一條 CI 安裝路徑。

## Risks / Trade-offs

**[R1] 非 git 目錄開始長出 `.claude/settings.local.json`]** → 這正是 Claude 自己的設定慣例,
不是我們發明的檔案;寫入走 jq merge,既有 key(如 livekit 那份很長的 `permissions.allow`)
完整保留。護欄擋掉 `$HOME` / `/` / `/tmp` 三種不該落地的情境;其餘目錄視為使用者刻意在那裡
工作。

**[R2] `/tmp` 下的 git repo 不再被種子(行為變更)** → 接受,且細看之下是**淨收益**而非單純的
代價。情境是 `git clone <url> /tmp/peek-at-lib` 或 `git worktree add /tmp/review-pr-123`
這類拋棄式 checkout:今天在那裡開 session 會種出 `~/.claude/memory/-tmp-peek-at-lib/`,但
`/tmp` 重開機即清空——那個記憶目錄會**永遠留在共享區,指向一個不存在的路徑,再也不會被任何
session 讀到**。每次臨時 clone 都留一個孤兒。護欄擋掉後記憶落回 Claude 預設的
`projects/<id>/memory/`(同樣拋棄式,但不污染共享區)。

實測現況衝擊為零:機器上 `/tmp` 底下 0 個 git repo;`worktree` skill 建立的是 repo 的兄弟
目錄(`../<repo>-<branch>`)而非 `/tmp`;`/tmp/claude-1000/` 只存放 scratchpad 與 tasks,
不含 worktree。此變更仍明確寫進 spec 場景,不當作隱性副作用。

**[R3] 正規化比對可能多重命中** → 例如 `foo_bar` 與 `foo-bar` 兩個目錄同時存在時會正規化成
同一個鍵。取 glob 排序後第一個 `memory/` 非空者(確定性),並在 stderr 印出實際採用的來源。
真實機器上不存在這種配對;若真發生,遷移錯的那份仍留在原地不會遺失,可手動更正。

**[R4] 非 git 目錄從子目錄開 session 會分到不同 `<id>`** → 接受。非 git 沒有可靠的「專案根」
定義(這正是 D2 拒絕 marker 檔的理由),而這個行為與 Claude 自身 `projects/` 的分桶完全一致,
不算退步。`CLAUDE_PROJECT_DIR` 在 hook 情境下已經給出 Claude 認定的專案根,實務上會落在對的桶。

**[R5] 遷移只在目標為空時發生** → 既有政策,不變。若使用者在懶遷移完成前就在新位置寫了記憶,
舊記憶會留在 `projects/<id>/memory/` 不被搬走(也不會被覆蓋)。stderr 已有警告路徑。

## Migration Plan

1. 改 script → 本機 `chezmoi apply` **只針對** `~/.local/bin/claude-memory-seed`
   (本機常比 repo 新,全量 apply 會退版)。
2. 在 `/home/howardwang/devops/opensearch`(只有 1 個記憶檔,爆炸半徑最小)手動跑一次
   `claude-memory-seed apply` 驗證遷移與寫入。
3. 驗證護欄:在 `$HOME` 與 `/tmp/xxx` 各跑一次,確認 `~/.claude/settings.local.json` **未**
   被建立/修改。
4. 其餘 3 個目錄交給下次開 session 的懶遷移。

**Rollback**:script 是純函式性的重寫,回滾即還原檔案;已被搬動的 `memory/` 目錄需手動搬回
`projects/<id>/memory/`,並刪掉新寫入的 `autoMemoryDirectory` key(其餘 key 未被動過)。

## Open Questions

無。四個決策點已於討論中定案(anchor 選擇、護欄範圍、懶遷移、測試補齊)。
