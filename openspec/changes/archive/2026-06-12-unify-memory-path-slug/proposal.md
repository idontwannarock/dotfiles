## Why

剛 ship 的 `claude-memory-seed` 只對 bare+worktree 生效,且 key 用 folder basename
(`~/.claude/memory/<basename>`)。這留下兩個缺口:

1. **一般 repo 的 worktree 沒被照顧**:一般 repo(非 bare)用 `git worktree add` 開出去的
   linked worktree,目前各自落在 `~/.claude/projects/<worktree-slug>/memory/`,彼此和主
   checkout 都不共用記憶。
2. **basename key 會撞桶**:擴大到所有 repo 後,`basename(dirname(common-dir))` 對一般 repo
   就是「repo 自己的資料夾名」,兩個同名 repo(不同路徑)會共用同一個 memory 桶 → 記憶交叉污染。

使用者要的是**所有 git repo 的 auto-memory 位置統一**,且不撞、跨 worktree 穩定。

(已研究 Codex 等其他工具:Codex memory 是全域 SQLite + 自有格式、無 `autoMemoryDirectory`
對等可重定位設定,**原生共享不可行**;因此 memory 維持 Claude 自家 `~/.claude/memory/`,
不搬 `~/.agent`。會在 reference 留一句說明。)

## What Changes

把 key 從 folder-basename 改成**正規路徑 slug**,並移除 bare-only gate,讓所有 git repo
統一:

- **統一 key**:`<id> = slug(dirname(realpath(git-common-dir)))`,即把 canonical repo root
  的絕對路徑 `/` 換成 `-`(= Claude 既有 projects slug 編碼)。`dirname(common-dir)` 對一般
  repo 是「`.git` 的父 = 主 checkout」、對 bare 是「`.bare` 的父 = 容器」,一條規則涵蓋兩者。
  目標 `~/.claude/memory/<id>`。完整路徑唯一 → 不撞;錨在 common-dir 父層 → 跨 worktree 穩定。
- **移除 bare-only gate**:`claude-memory-seed` 改為對**任何有 toplevel 的 git repo**生效
  (非 git / 缺 jq 仍 no-op)。
- **自動遷移既有記憶(seeder 內,path-based)**:目標 `~/.claude/memory/<id>/` 空/不存在時,
  依序 `mv` 舊記憶過來:① 舊 basename `~/.claude/memory/<basename>/` ② Claude 預設
  `~/.claude/projects/<id>/memory/`。**只搬 `memory/`、不動 transcripts**。目標已有內容 →
  不覆蓋、不搬,只設 override(衝突留手動處理並印警告)。
- **放寬覆寫政策**:現值缺、或落在受管根(`~/.claude/memory/`、`~/.claude/projects/`)→ 更新為
  canonical;指向受管根以外(真自訂)→ 尊重不動。讓剛 ship 的 basename 值自動升級。
- **localfiles 一致**:`local-files-store` 的 `<repo-id>` 同步從 basename 改成相同 path-slug,
  兩機制對同一 repo 解析到同名 key;既有 store 目錄一併 rename 遷移(目前機器上為空,無負擔)。

## Capabilities

### Modified Capabilities

- `claude-memory-seed`: key 推導(basename → path-slug)、適用範圍(bare-only → 所有 git repo)、
  新增自動遷移、放寬覆寫政策。
- `local-files-store`: `<repo-id>` 推導從 `basename(dirname(realpath(common)))` 改為
  `slug(dirname(realpath(common)))`,與 memory key 一致。

## Impact

- **修改檔案**:
  - `dot_local/bin/executable_claude-memory-seed` —— key 改 path-slug、移除 .bare gate、加遷移、放寬覆寫。
  - `dot_local/bin/executable_localfiles` —— `repo_id()` 改 path-slug。
  - `dot_agent/reference/bare-worktree/claude-state.md` —— 更新 key 描述為 path-slug + 統一全 repo;補一句「Codex 等其他工具 memory 不可原生共享」。
  - `dot_agent/reference/local-files/index.md` —— `<repo-id>` 推導描述同步改 path-slug。
- **不變**:`dot_config/git/hooks/executable_post-checkout`(呼叫不變)、`modify_settings.json.sh.tmpl` 的 SessionStart(呼叫不變)。
- **一次性遷移**:機器上既有 2 個 `~/.claude/memory/<basename>`(shoalter、hktv...)由 seeder 遷移步驟①自動 rename 到 path-slug;localfiles store 目前為空。dotfiles 自己(本 repo)會在套用後**下個 session** 從 `projects/<id>/memory` 遷到 `~/.claude/memory/<id>`(刻意不在本 session 手動觸發,以免搬走 active session 的記憶)。
- **blast radius**:此後**所有** git repo 的 auto-memory 都會在下次開啟時遷到 `~/.claude/memory/<id>`(各自 idempotent、安全)。transcripts 不動,`--resume` 不受影響。
- **已知邊角**:slug 採 `/`→`-`;若路徑含 Claude 另行編碼的字元(如 `.`),遷移來源比對可能 miss → 該 repo 從新位置全新開始(舊的留原地不丟失)。
