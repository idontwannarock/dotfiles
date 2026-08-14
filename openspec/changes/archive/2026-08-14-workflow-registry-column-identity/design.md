## Context

registry 有兩個獨立的識別問題，兩者的成因相同：**spec 沒說的那些欄位，每個寫入者各自解讀**。

第三欄從 project-memory 路徑改成 active-workflows 路徑時，body 三處都跟著改了，spec 的欄名沒改。於是欄名與用途分離，資料按寫入時間裂成兩半。

`Repo` 欄從未被規範，於是出現裸名、帶 `-` 的 slug、不帶 `-` 的 slug 三種。前導 `-` 不是排版細節——`slug(dirname(realpath(git-common-dir)))` 的輸入是絕對路徑，第一個字元必然是 `/`，所以正典 slug 必然以 `-` 開頭。少一個 `-` 就是另一個目錄。

本機的實際後果：`~/.agent/workflows/` 有兩組成對目錄，其中 `shoalter-ai-toolkit/` 裡有一筆 2026-06-16 的 workflow 列，而正典的 `-home-howardwang-ws-github-shoalter-ai-toolkit/` 是空的。任何新 session 在該 repo 都會回報「無進行中流程」。

## Goals / Non-Goals

**Goals:**

- spec 的欄名與 body 的用法一致，且此後任何寫入者對每一欄的內容得出同一個答案。
- `Repo` 欄的形式可機械驗證，並與 `principles.md` 的單一 repo 身分定義綁定，而不是複製一份。
- 本機資料收斂到正典形式。

**Non-Goals:**

- 不改 body——這次是 spec 追上 body，不是相反。
- 不改 `active_workflows.md` 的欄位。
- 不處理「有 worktree 卻沒登記」這類反向落差（`shoalter-ai-toolkit` 的 `add-admin-console` 即為一例），那是另一個問題。

## Decisions

### D1. 正名成 `Active Workflows Path`，不是把 body 改回 memory 路徑

兩個方向都能消除分歧。選擇改 spec，因為 body 描述的才是實際運作的機制：`active_workflows.md` 是流程真正會讀寫的檔案，而 project memory 路徑早已由 memory-hook 自行以 path-slug 推導，不需要 registry 代為記錄。把 body 改回去等於復活一個沒有讀者的欄位。

### D2. `Repo` 欄指向 `principles.md` 的定義，不複製定義本身

spec 只斷言「SHALL 為正典 repo slug」並指出定義所在，不重述 `slug(dirname(realpath(git-common-dir)))` 這串。規則寫一處；複製一份的代價是兩處會各自漂移，而這正是本 change 在修的病。

### D3. 用「後果」而非「格式」寫 scenario

<!-- evergreen-candidate -->
非正典 slug 的問題不是不好看，是**同一個 repo 的產物會落在互相看不見的目錄，且失敗是靜默的**——寫得出來、找得到、只是找不到別人寫的那些。scenario 因此斷言後果（產物必須落在同一個目錄）而非字面格式，這樣它同時涵蓋 slug、handoff 目錄與未來任何以 repo 為單位的產物，而不必每加一種產物就補一條。

### D4. 本機遷移一次做完，不留半套

欄名改、slug 正規化、分裂目錄合併、已死列清除，四件事要一起做。只做前兩件會留下 registry 指向正典目錄、而資料還在舊目錄的狀態——比原本更難診斷，因為兩邊看起來都「對」。

已死列的判定不靠年份：`add-self-service-portal` 的 worktree 目錄不存在，且該分支在 `.bare` 的 `worktree list` 與 branch 清單中皆查無此項。body 2c 既有的「Clean stale entries (missing worktree paths, deleted branches)」正是為此而寫。

## Risks / Trade-offs

- **刪除分裂目錄不可回復（`~/.agent/` 無版控）** → 刪除前先把三個目錄的完整內容列進 tasks 作為紀錄；兩個是空表頭，第三個的唯一一列已用兩項獨立證據（worktree 不存在、branch 不存在）確認為死。
- **遷移只對這台機器有效** → 這是 registry 的既有性質（per-machine、不同步），非本 change 引入。其他機器在下次寫入時依新 spec 收斂。
- **spec 改欄名後，其他機器的舊資料仍是舊欄名** → 讀取端靠位置與內容形態辨識，不靠欄名字串比對；欄名是給人看的。
