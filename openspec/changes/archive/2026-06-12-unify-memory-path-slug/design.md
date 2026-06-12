# Design — unify-memory-path-slug

## 目標與心智模型

把「同一 repo 的所有 checkout/worktree 共用一份 auto-memory」這件事,從只支援
bare+worktree 擴大到**所有 git repo**,並用一個**抗撞、跨 worktree 穩定**的 key。

關鍵洞見:key 要同時滿足「跨 worktree 穩定」與「跨 repo 不撞」,就**不能**從當前 cwd
或資料夾名推 —— 必須錨在 repo 的**正規路徑**。`dirname(realpath(git-common-dir))` 正好
給出這個錨點:

- 一般 repo(主 checkout 或其 linked worktree):common-dir 都指向主 `.git` →
  `dirname` = 主 checkout 路徑。
- bare+worktree(任一 worktree):common-dir = `<container>/.bare` →
  `dirname` = 容器路徑。

兩者都對「同一 repo 的所有 worktree」回傳同一條絕對路徑。把它 slug 化即得 key。

## 統一 key

```
canonical = dirname(realpath(git rev-parse --git-common-dir))
id        = canonical 把 "/" 換成 "-"            # = Claude projects slug 編碼
autoMemoryDirectory = ~/.claude/memory/<id>
```

驗證(實測):
- `/home/howardwang/ws/github/dotfiles` → `-home-howardwang-ws-github-dotfiles`
  (與現有 `~/.claude/projects/-home-howardwang-ws-github-dotfiles/` 目錄名字字相符)
- `/home/howardwang/ws/github/shoalter-ai-toolkit`(bare 容器)→
  `-home-howardwang-ws-github-shoalter-ai-toolkit`

slug 採 `/`→`-` 單一規則。target id 由我們掌控、保證一致;遷移來源比對見下。

## seeder 流程(`claude-memory-seed apply`)

```
1. toplevel/common 取得;非 git → exit 0
2. canonical = dirname(realpath(common));  id = slug(canonical);  target = ~/.claude/memory/<id>
3. 缺 jq → exit 0(不阻斷)
4. 遷移(僅當 target 不存在或空):依序找來源,第一個命中就 mv 其 memory/ 進 target
     a. ~/.claude/memory/<basename(canonical)>/        # 舊 basename 方案
     b. ~/.claude/projects/<id>/memory/                 # Claude 預設(只搬 memory/,不動 transcripts)
   target 已有內容 → 不搬、印警告(衝突手動處理)
5. 覆寫政策:讀 settings.local.json 現值
     - 缺、或值的開頭是 ~/.claude/memory/ 或 ~/.claude/projects/ → 寫入 canonical target
     - 否則(受管根以外的真自訂)→ 不動
6. 寫入時保留其他 key、LF 結尾
```

移除舊版的 `.bare` gate。非 bare 的一般 repo 也會 seed/遷移。

### 為何遷移用 path-based 而非 session context

遷移完全由 `canonical` 路徑推導(來源 a/b 都是純路徑),不需 SessionStart 的
transcript_path。好處:post-checkout(無 session)與 SessionStart 兩個觸發點行為一致。
代價:來源 (b) 的 `<id>` 必須等於 Claude 實際 projects 目錄名;若路徑含 Claude 另行編碼
的字元(如 `.`),比對會 miss → 該 repo 從新位置全新開始(舊的留原地、可手動搬,無資料損毀)。

### 遷移安全

- 只在 target **空/不存在**時搬 → 不會覆蓋已遷移/使用中的記憶。
- 只 `mv` `memory/` 子目錄 → transcripts(`projects/<id>/*.jsonl`)留原地,`--resume` 不受影響。
- 多次執行 idempotent:第二次 target 已有內容 → 跳過搬移;覆寫政策對相同 canonical 值是 no-op diff。

## localfiles 一致

`local-files-store` 的 `repo_id()` 從 `basename(dirname(realpath(common)))` 改成
`slug(dirname(realpath(common)))`,與 memory key 同式 → 兩機制對同一 repo 解析到同名 key,
也順帶讓 localfiles 不再撞桶。store 佈局 `${XDG_STATE_HOME}/localfiles/<repo-id>/...` 不變,
只是 `<repo-id>` 變成 path-slug。既有 store 目錄需 rename 遷移(目前機器上為空,無負擔;
helper 不內建 localfiles 遷移,因為改動當下 store 多半空或可手動處理)。

## 觸發點(不變)

A(全域 SessionStart hook)與 C(post-checkout dispatcher 那行)呼叫不變,只是 helper 內部
邏輯更新。`modify_settings.json.sh.tmpl`、`dot_config/git/hooks/executable_post-checkout`
本次不需改。

## 一次性遷移(機器現況)

- `~/.claude/memory/shoalter-ai-toolkit` → seeder 步驟 4a 自動 rename 成
  `-home-howardwang-ws-github-shoalter-ai-toolkit`(於 shoalter 下次開啟時);實作時會在
  shoalter worktree 實跑 `apply` 驗證升級正確。
- `~/.claude/memory/hktv-product-category-classification-api-poc` → 同理,於該 repo 下次開啟時遷移。
- dotfiles 自己:留待套用後下個 session 自動遷移(本 session 不手動觸發,避免搬走 active 記憶)。

## 與 Codex 等工具(研究結論,寫進 reference)

Codex memory 為全域 `~/.codex/memories/` markdown + SQLite state,無 `autoMemoryDirectory`
對等可重定位設定(只能 `CODEX_HOME` 整包搬)、且為全域非 per-project。跨工具原生共享 memory
今天不可行(業界走 MCP memory server 如 Mem0 當中介)。故 memory 維持 Claude 自家
`~/.claude/memory/`,不搬 `~/.agent`;claude-state.md 留一句說明。
