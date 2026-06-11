## Why

`.env`、`.env.local`、`.env.*.local` 這類**被 git ignore 的本地秘密檔**有一個跨 branch / worktree 的痛點:它們不在版控裡,所以

1. **切 branch 不帶著走** —— 在一般 repo 切 branch 時檔案還在,但開新的 git worktree(或 bare+worktree 佈局下每個 worktree)時,新資料夾裡沒有這些檔,工具(dotenv、docker-compose、app)在 cwd 找不到就壞掉。
2. **沒有單一可信來源** —— 同一個 repo 的多個 worktree 各自一份 `.env`,容易分歧,也沒有「機器上唯一一份備份」。

現有 `bare-worktree/claude-state.md` 已點名「`.env` 是新 worktree 唯一無法自動補齊的東西」,但只能「提示缺檔」,沒有補齊機制。

## What Changes

新增一套 **local-files store** 機制,讓被管理的 gitignored 本地檔在「任意 repo 的任意 branch / 任意 worktree」都能被自動補齊,且不受切 branch / worktree 影響:

- **全域 store**:`${XDG_STATE_HOME:-~/.local/state}/localfiles/<repo-id>/` 下,以 `_default/` 為共用桶、需要時才開 `<branch>/` override 桶,保存被管理檔的耐久副本。
- **`localfiles` helper**(`~/.local/bin/localfiles`):`restore`(store→worktree,**只在缺檔時填補**)與 `backup`(worktree→store;`--branch` 寫進 branch 桶)兩個子命令,封裝 repo-id 推導與桶解析。
- **全域 post-checkout dispatcher**(`~/.config/git/hooks/post-checkout`):先跑 `localfiles restore`,再 chain repo-local `.githooks/post-checkout` 與 `.git/hooks/post-checkout`(realpath 比對防自我遞迴),作為多工器不靜默吃掉其他 repo 的 hook。
- **裝一次全機器生效**:chezmoi 以 `run_onchange_` 設定 `git config --global core.hooksPath`(idempotent,設前檢查既有值),hooks 目錄與 helper 皆由 chezmoi 管理並隨更新自動跟上。
- **Authority 已定**:**全域 = 備份、in-folder = 工作 source**;restore 只填補缺檔,backup 由顯式 helper 負責,貼合 git 只有 checkout 事件、無「離開 worktree / 檔案被編輯」hook 的能力邊界。
- **Reader 兩者都要**:copy 進資料夾讓一般工具在 cwd 看得到;另有 agent read-fallback 規則(cwd 找不到 → 去 store 桶找)寫進 reference。
- **整合既有 bare 設定**:`bare-worktree/setup.md` 收掉 `core.hooksPath .githooks` 那行(改為依賴 global dispatcher),並交叉連結到新 reference;`claude-state.md` 的「`.env` 無法自動補齊」一節更新為指向 local-files。

## Capabilities

### New Capabilities

- `local-files-store`: 被管理的 gitignored 本地檔(`.env*`)的跨 branch/worktree 補齊機制 —— 全域 store 佈局、`localfiles` helper 的 restore/backup 語意(全域=備份、in-folder=source)、per-branch 桶解析、global `core.hooksPath` dispatcher 的安裝與多工、以及 agent read-fallback 規則。

### Modified Capabilities

(無既有 spec 需修改。`agent-reference-layout` 管轄 reference 的「配置/位置」,不涉本變更的 store 機制;bare-worktree 的 `core.hooksPath .githooks` 僅為 reference 內文,非 spec 化需求,直接隨文件更新。)

## Impact

- **新增檔案(reference,純 `.md`)**:`dot_agent/reference/local-files/index.md`、`setup.md` → 部署為 `~/.agent/reference/local-files/*.md`。
- **新增檔案(可執行)**:`dot_local/bin/executable_localfiles`(POSIX sh helper)→ `~/.local/bin/localfiles`;`dot_config/git/hooks/executable_post-checkout`(POSIX sh dispatcher)→ `~/.config/git/hooks/post-checkout`。
- **新增檔案(安裝)**:`run_onchange_set-git-hookspath.sh.tmpl`(非 Windows)、`run_onchange_set-git-hookspath.ps1.tmpl`(Windows)→ `git config --global core.hooksPath` 指向絕對的 `~/.config/git/hooks`。
- **修改檔案**:`dot_agent/reference/bare-worktree/setup.md`(收掉 hooksPath 行 + 交叉連結)、`dot_agent/reference/bare-worktree/operating.md`(remove-worktree 不影響 store 的註記,如需要)、`dot_agent/reference/bare-worktree/claude-state.md`(`.env` 一節改指向 local-files)。
- **跨平台**:helper 與 dispatcher 為 POSIX sh,git hooks 在 Windows 由 git-bash 執行,三平台一致;`localfiles backup` 手動執行於 Windows 需在 git-bash 內。
- **blast radius**:設定 global `core.hooksPath` 會影響機器上**所有** repo 的 hook 解析;dispatcher 設計為多工器以保留 repo-local `.githooks/` 與 `.git/hooks/`。現有 bare repo 需 `git --git-dir=.bare config --unset core.hooksPath` 才會改吃 global(reference 附遷移註記)。
