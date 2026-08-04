## 1. 測試骨架與現況迴歸鎖定

先建立可紅可綠的迴路,並把**現行 git 行為**鎖進測試,再開始改 script。D1 的 worktree
不對稱(共享 `<id>`、各自 settings)是最容易被靜默破壞的一點,必須在重構前就有測試守著。

- [x] 1.1 建立 `tests/claude-memory-seed.test.sh`:手捲 POSIX `sh` runner,黑箱地以
      `sh <script> apply|where` 驅動,`HOME` 指向臨時目錄以隔離真實記憶;顯式斷言 `jq` 與
      `git` 可用(缺席時紅燈,而非讓 script 的安靜 no-op 造成假綠燈)。
- [x] 1.2 為**現行**行為補迴歸測試(此時應全綠,不改 script):一般 repo 推導 slug、
      worktree 共享同一 `<id>`、worktree 的 settings 寫在自身 toplevel、
      受管根以外的自訂值不被覆寫、重複執行 idempotent。
- [x] 1.3 新增 `.github/workflows/test-shell.yml`(`ubuntu-latest`,迴圈跑 `tests/*.test.sh`)。
      開新檔而非塞進 `test-pester.yml`:repo 慣例是一個 workflow 一個關注點
      (`test-tools-build.yml` 即另一例),且兩者需要不同 runner;不動既有綠燈 workflow。
      → verify:CI 綠燈且該 job 確實有跑到斷言(非 0 tests)。

## 2. 拆開 id 錨點與設定落點(行為不變的重構)

- [x] 2.1 在 script 內引入 `id_root` / `settings_root` 兩個變數,git 路徑的取值來源與現行
      完全相同(`canonical_root()` / `$toplevel`);`repo_id()` 改讀 `id_root`,寫入路徑改讀
      `settings_root`。
      → verify:1.2 的迴歸測試維持全綠,行為逐位元不變。
- [x] 2.2 兩者統一以 `CDPATH= cd -- "$x" && pwd -P` 正規化。新增 symlink 專案目錄解析到同一
      `<id>` 的測試(依賴 2.1)。

## 3. 寫入護欄(先於解除 non-git gate)

護欄必須先落地。順序反過來的話,中間會存在一個「非 git 已解除但 `$HOME` 未擋」的版本,
在 `$HOME` 開一次 session 就會寫壞 user-level settings。

- [x] 3.1 新增護欄:`settings_root` 為 `$HOME`、`/`、或位於 `/tmp/` 之下時安靜 exit 0,
      且不建立 `.claude/`、不寫檔、不執行遷移。統一套用,不分 git 與否(依賴 2.1)。
- [x] 3.2 補護欄測試:`$HOME`(非 git)、`$HOME`(本身是 git repo)、`/tmp/<x>`(git 與非 git
      各一)、`/` 四種情境皆未產生檔案。
      → verify:含「`/tmp` 下的 git repo 不再被種子」這條刻意的行為變更。

## 4. 解除 non-git gate

- [x] 4.1 移除 `[ -n "$toplevel" ] || return 0`,改為 `canonical_root()` 失敗時
      `id_root` / `settings_root` 皆 fallback 到 `${CLAUDE_PROJECT_DIR:-$PWD}`
      (依賴 3.1)。`where` 子命令同步適用。
- [x] 4.2 補非 git 測試:非 git 目錄以自身為錨點、`CLAUDE_PROJECT_DIR` 優先於 cwd、
      該變數未設時 fallback 到 cwd 且不失敗。

## 5. 修遷移來源查找

- [x] 5.1 來源 ② 從字串拼接改為掃 `~/.claude/projects/*/`,兩邊 basename 的 `[-_.]` 正規化
      為 `-` 後比對,取第一個 `memory/` 非空者,並把實際採用的來源印至 stderr。
      `~/.claude/projects/` 不存在時安靜略過(POSIX `sh` 無 `nullglob`,靠迴圈內 `[ -d ]` 過濾)。
- [x] 5.2 補測試:含底線的路徑能命中 Claude 的 `-` 桶名、`projects/` 不存在時不報錯、
      目標已有內容則不覆蓋、既有 settings 其他 key 原封保留。

## 6. 文件與 spec 收尾

- [x] 6.1 更新 script 檔頭註解:適用範圍(git + 非 git)、三道護欄、遷移來源比對方式。
- [x] 6.2 `home/dot_agent/reference/bare-worktree/claude-state.md` 補一句非 git 專案目錄的
      適用說明與護欄邊界。
- [x] 6.3 `openspec validate support-non-git-memory-seed` 通過;確認 delta spec 的每個
      scenario 都有對應測試。對照時補上兩個缺口:bare+worktree 以容器為 id、
      舊 basename 目錄升級(後者正是 `try_migrate` 的第一個來源,本次改動到卻原本沒測)。

## 7. 本機實測(依 design 的 Migration Plan)

- [x] 7.1 `chezmoi apply` **只針對** `~/.local/bin/claude-memory-seed`(本機常比 repo 新,
      全量 apply 會退版)。
- [x] 7.2 在 `/home/howardwang/devops/opensearch` 驗證部署版 script 對真實資料的行為。
      **實作期間情況有變**:使用者在 opensearch / monitor / hr-chatbot 三處開 session,
      懶遷移已自行完成(記憶就位、settings 正確、transcripts 留在原地),故本項改驗
      idempotency——再跑一次 apply,settings、記憶內容、transcripts 三者的 checksum 皆未變動。
      這同時實地驗證了 7.4 依賴的懶遷移路徑確實可行。
- [x] 7.3 護欄實測:在 `$HOME` 與 `/tmp/<x>` 各跑一次,確認
      `~/.claude/settings.local.json` **未**被建立或修改。
      → verify:這是本次唯一會造成資料損害的失敗模式,必須實機驗過。
- [x] 7.4 懶遷移:hr-chatbot(7 檔)、monitor(3 檔)已於實作期間隨開 session 自行完成。
      **livekit(30 檔)刻意留著**——它是唯一還沒遷移的,下次在該目錄開 session 時自動搬,
      不手動觸發。
