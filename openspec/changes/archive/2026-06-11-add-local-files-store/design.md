# Design — local-files-store

## 約束與心智模型

git 只在 **checkout 類事件**(branch checkout、`worktree add`)觸發 hook;**沒有**「離開 worktree」或「檔案被編輯」的 hook。因此「自動把 in-folder 編輯即時推回全域」本質上做不到可靠。據此定 authority:

- **全域 store = 耐久備份 / 新 worktree 的種子**
- **in-folder 那份 = 工作中的 source of truth**
- `restore` 只在 **cwd 缺檔**時填補(絕不覆蓋你正在編輯的那份);`backup` 由使用者**顯式**呼叫,把目前這份推回全域。

## repo-id 推導(跨 branch/worktree 須穩定一致)

```
repo_id = basename( dirname( realpath( git rev-parse --git-common-dir ) ) )
```

- 一般 repo 主工作樹:common-dir=`<repo>/.git` → repo_id=`<repo>`。
- 一般 repo 的 linked worktree:common-dir 仍指向主 `<repo>/.git` → repo_id=`<repo>`,跨 worktree 一致。
- bare+worktree:common-dir=`<container>/.bare` → repo_id=`<container>`,跨 worktree 一致。

同名不同 repo 會撞桶 —— 已知取捨,先求簡單,日後可改 remote-url slug。

## Store 佈局與桶解析

```
${XDG_STATE_HOME:-$HOME/.local/state}/localfiles/<repo-id>/
    _default/            # 共用桶(main/dev 與多數 branch)
    <branch>/            # 需要時才開的 per-branch override 桶
```

- branch = `git symbolic-ref --short -q HEAD`;detached HEAD → 視為 `_default`。
- **restore** 桶優先序:`<branch>/` 存在則用之,否則 `_default/`。→ 達成「`_default` 共用 + on-demand branch override」。
- **backup** 目標:`localfiles backup` 寫 `_default/`;`localfiles backup --branch` 寫 `<branch>/`(等同把此 branch opt-in 成獨立桶,之後 restore 自動優先它)。

## 被管理清單(約定固定)

repo 頂層(`git rev-parse --show-toplevel`)下的:

```
.env   .env.local   .env.*.local
```

v1 只處理頂層、只處理檔案(不遞迴、不含大型 data 目錄 —— 大檔複製成本高且多半 regenerable)。日後遇到再加。

## `localfiles` helper 介面

```
localfiles restore            # store→cwd repo,只填補缺檔
localfiles backup [--branch]  # cwd repo→store(_default 或 branch 桶)
localfiles where              # 印出此 repo 的 store 路徑(除錯用)
```

- 非 git repo 內呼叫 → 安靜結束(restore)或報錯(backup)。
- restore 對工具透明:檔案出現在預期路徑,dotenv/compose 直接讀得到。

## 全域 dispatcher(`~/.config/git/hooks/post-checkout`)

```sh
#!/bin/sh
# 1) localfiles restore(失敗不阻斷 checkout)
command -v localfiles >/dev/null 2>&1 && localfiles restore || true

# 2) 多工:chain repo-local hooks,但不自我遞迴
self=$(realpath "$0" 2>/dev/null)
for h in "$(git rev-parse --show-toplevel 2>/dev/null)/.githooks/post-checkout" \
         "$(git rev-parse --git-common-dir 2>/dev/null)/hooks/post-checkout"; do
    [ -x "$h" ] || continue
    [ "$(realpath "$h" 2>/dev/null)" = "$self" ] && continue   # 防自我遞迴
    "$h" "$@"
done
```

設計理由:global `core.hooksPath` 一旦設定,git **只**跑該目錄的 hook,不再自動跑 `.git/hooks` 或 repo-local `core.hooksPath`。dispatcher 因此必須自己 chain repo-local hooks,否則會靜默吃掉其他 repo 既有的 post-checkout(例如 bare 佈局用來 seed `autoMemoryDirectory` 的那支)。realpath 比對防止 dispatcher 把自己當 repo hook 再呼叫一次。

## 與既有 bare 設定整合

`bare-worktree/setup.md` 現行指示 `git --git-dir=.bare config core.hooksPath .githooks`。**repo-local config 覆蓋 global**,所以這行會讓 bare repo 反而不吃 global dispatcher → 收掉這行,改為依賴 global dispatcher 自動 chain `.githooks/post-checkout`。現有機器上的 bare repo 需 `git --git-dir=.bare config --unset core.hooksPath` 一次性遷移(reference 附註記)。

## 安裝(chezmoi)

- hooks 目錄與 helper 由 chezmoi 直接部署(`executable_` 前綴給可執行位)。
- `run_onchange_set-git-hookspath`(sh + ps1 兩變體,OS-gated):idempotent 設定 `git config --global core.hooksPath "<abs>/.config/git/hooks"`。設前讀既有值:若已是目標路徑則跳過;若指向**其他**非預期值則印警告不覆蓋(避免踩使用者既有自訂)。

## Agent read-fallback(寫進 reference,非程式碼)

copy 已讓檔案出現在資料夾,fallback 只在「restore 尚未跑 / 檔案僅存在於全域」時用:

> agent 要讀 `.env` 類檔案而 cwd 內找不到時,先去 `${XDG_STATE_HOME:-~/.local/state}/localfiles/<repo-id>/<branch>/` 再 `_default/` 找;找到就讀(in-folder=source,故只讀不自動覆寫回資料夾),仍無才視為缺檔並提示。
