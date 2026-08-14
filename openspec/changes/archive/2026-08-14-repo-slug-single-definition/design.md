## Context

「規則寫一處，別處只放單向指路」這條原則，在被違反時的症狀不是重複，而是**分歧**：複本一旦存在就會各自漂移，而讀者無從得知哪一份是對的。

這次的實例特別乾淨：同一份 spec 裡，指路那句（`Repo` 欄）與兩份複本（`首次在 repo 開啟` scenario、`Active Workflows Index` requirement）同時存在，且兩份複本都缺 `dirname` 與 `realpath`。也就是說複本不只是多餘，它們已經是錯的——這正是原則預測的結果，只是通常要等更久才顯現。

## Goals / Non-Goals

**Goals:**

- `slug(dirname(realpath(git-common-dir)))` 這串在 `principles.md` 以外一次都不出現，且引用它的每一處都指得回去。
- body 與 spec 對 slug 的說法一致。

**Non-Goals:**

- 不改 `principles.md` 的定義本身。
- 不動 `~/.agent/` 的資料（前一個 change 已收斂）。
- 不重寫兩則 requirement 的其他內容。

## Decisions

### D1. 指路，而非把定義補完整

兩處都可以「補上 `dirname`/`realpath` 讓它變正確」。不這樣做，因為那會留下三份正確的複本，而三份複本仍然會漂移——只是下次漂移得更慢、更難發現。原則管的是複本存在與否，不是複本此刻對不對。

### D2. body 也指路，即使 body 的讀者是模型

body 的既有寫法（「slugify the result with `/`→`-`」）比 spec 更具體，因此更容易被照字面執行。改成指向 `principles.md` 有一個代價：模型要多讀一份檔案才拿得到完整算式。

接受這個代價，因為替代方案是讓一份會被逐字執行的文件持有一份可能過期的算式。而 `context/` 本來就是需求分析時會讀的東西，不是遙遠的引用。

### D3. 保留「這一步為什麼在 bare+worktree 下會錯」的說明

body 的 ARCH dispatch table 講的是「自動推導在 bare+worktree 下是錯的」，那是**判斷**不是定義，要留著。只把定義的算式換成指路。

## Risks / Trade-offs

- **指路的目標若改名，指路就斷** → `principles.md` 的該條標題已被前一個 change 引用一次，本次再引用一次；兩處用同一段標題文字，改名時會一起被搜到。
- **模型可能不去讀被指向的檔案，於是自己編一個推導** → 減損有限：`~/.agent/workflows/` 底下既有目錄全是正典形式，任何自創的推導在第一次比對既有目錄時就會露餡。
