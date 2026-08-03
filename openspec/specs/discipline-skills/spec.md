# discipline-skills Specification

## Purpose
定義自家開發紀律 skills(grill/tdd/diagnose/verify-done/worktree/finish-branch)的跨工具(Claude/Codex)部署方式與各自行為契約。
## Requirements
### Requirement: 跨工具部署
六個自家流程/紀律 skills(`grill`、`tdd`、`diagnose`、`verify-done`、`worktree`、`finish-branch`)SHALL 以 chezmoi shared-body(`home/.chezmoitemplates/skills/<name>.md`)+ per-tool name-map wrapper 部署,Claude 與 Codex 共用同一份身體。

#### Scenario: chezmoi apply 後雙工具可用
- **WHEN** `chezmoi apply` 完成
- **THEN** `~/.claude/skills/<name>/SKILL.md` 與 `~/.codex/skills/<name>/SKILL.md` SHALL 存在且由同一份 shared body 渲染,skill 引用依各工具 name-map 呈現(Claude 用 namespaced 名稱、Codex 用 `$` sigil)

#### Scenario: 不再依賴 superpowers symlink
- **WHEN** 檢查 `~/.codex/skills/`
- **THEN** SHALL NOT 存在指向 Claude plugin cache 的 superpowers symlink,`install-superpowers-codex.sh` SHALL 不存在於 chezmoi source

### Requirement: grill 訪談紀律
`grill` SHALL 以一次一題的訪談把模糊想法收斂成共識:每題附建議答案;能從環境查到的事實自己查、決策問使用者;解法有分岔時提出 2-3 個方案與推薦;每一題都必須可能改變後續行為。訪談開場,grill SHALL 讀取 `context/`(若存在)作為 domain grounding,併入其「事實自己查」紀律,避免重問已記載的背景。grill SHALL NOT 寫入 `context/`;凡發現疑似長青的 domain 詞彙或反覆適用原則,SHALL 以候選標記(如 `<!-- evergreen-candidate -->`)記入 `design.md` 的 `## Decisions`,待 sync/archive 階段對照實作再決定晉升。

#### Scenario: 單一 stop-gate
- **WHEN** 使用者尚未明確確認「共識達成」
- **THEN** Claude SHALL NOT 開始撰寫 openspec artifacts 或實作

#### Scenario: 產出分流
- **WHEN** 使用者確認共識達成
- **THEN** 結論 SHALL 直接分流至 openspec artifacts(決策→design.md Decisions;動機範圍→proposal.md;行為要求→spec delta),grill SHALL NOT 產生獨立的 design 文件

#### Scenario: 開場讀 context 當 grounding
- **WHEN** grill 訪談開始且 `context/` 存在
- **THEN** grill SHALL 先讀取它作為 domain 背景,SHALL NOT 重問其中已記載的事實

#### Scenario: 長青候選標記而非寫入
- **WHEN** 訪談中出現疑似長青的 domain 詞彙或反覆適用原則
- **THEN** grill SHALL 將其以候選標記記入 `design.md`,SHALL NOT 直接寫入 `context/`

### Requirement: tdd 循環紀律
`tdd` SHALL 只在預先同意的 seam 上測試(seam 於 grill / design 階段決定並記錄於 design.md),以垂直切片循環:red before green、一次一片、refactoring 不在循環內、mock 只在系統邊界。

#### Scenario: 實作期間套用
- **WHEN** `openspec-apply-change` 進行中且任務有可測 seam
- **THEN** Claude SHALL 依 tdd 循環實作(先看測試失敗,再寫實作)

#### Scenario: 無可測 seam
- **WHEN** 任務無可測 seam 或不值得建測試設施
- **THEN** Claude SHALL 明說跳過 tdd,結果正確性由 verify-done 把關

### Requirement: diagnose 除錯紀律
`diagnose` SHALL 以 feedback loop 為先:先建立能穩定重現失敗的命令,之後才允許提出假設;假設 SHALL 為 3-5 個可否證項目並排序;一次只驗證一個變數。

#### Scenario: 硬 gate
- **WHEN** 尚無能穩定變紅的重現命令
- **THEN** Claude SHALL NOT 提出根因假設或著手修復

#### Scenario: regression test 的 seam 判斷
- **WHEN** 根因確定、準備修復
- **THEN** Claude SHALL 先在正確的 seam 寫 regression test;若不存在正確的 seam,SHALL 將此事實回報為發現而非硬寫測試

### Requirement: verify-done 證據紀律
`verify-done` SHALL 要求在宣稱「完成 / 修好 / 通過」之前實際執行驗證命令並確認輸出;測試失敗時 SHALL 如實回報並附輸出。

#### Scenario: 完工宣稱前驗證
- **WHEN** Claude 準備宣稱實作完成
- **THEN** SHALL 先執行驗證命令並以實際輸出為證據

### Requirement: worktree 與 finish-branch 雙架構支援
`worktree` 與 `finish-branch` SHALL 原生支援 normal 與 bare-worktree 兩種 repo 架構,依 ARCH 偵測自動選擇對應機制,不依賴外部 override 說明。

#### Scenario: normal 架構下建立工作區
- **WHEN** ARCH=normal 且需要新工作區
- **THEN** `worktree` SHALL 以最新的 `main` 為明確起點建立 worktree(命令含 `main` start-point),SHALL NOT 從當前 HEAD 分支

#### Scenario: bare-worktree 下建立工作區
- **WHEN** ARCH=bare-worktree 且需要新工作區
- **THEN** `worktree` SHALL 以 `git --git-dir=.bare worktree add -b <branch> <branch> main` 建立(目錄與 branch 同名,無強制前綴),並依 bare-worktree 的手動規則(autoMemoryDirectory key)解析 registry 後登記 active_workflows

#### Scenario: finish-branch 選項行為
- **WHEN** 使用者選擇 Keep 或 Push + PR(PR 尚未 merge)
- **THEN** `finish-branch` SHALL 保留 worktree 與 branch,SHALL NOT 移除 active_workflows row(僅更新 status/step)

#### Scenario: finish-branch 失敗中止
- **WHEN** merge/rebase 序列中任一命令失敗(含 `--ff-only` 失敗)
- **THEN** `finish-branch` SHALL 立即停止,SHALL NOT 執行後續 dispose 或 row 移除,並回報狀態

#### Scenario: bare-worktree 下收尾
- **WHEN** ARCH=bare-worktree 且執行 `finish-branch` 的本地 merge
- **THEN** SHALL rebase 後從 `main/` worktree 以 `--ff-only` merge;merge 確認完成後才處置 worktree 與 branch,全程不需查閱額外 override 文件

#### Scenario: Discard 確認 gate
- **WHEN** 使用者選擇 Discard(捨棄未 merge 的工作)
- **THEN** `finish-branch` SHALL 在執行 `git branch -D` 前再次向使用者確認

#### Scenario: Push + PR 的 PR 合併後收尾
- **WHEN** 使用者選擇 Push + PR 且該 PR 已 merge
- **THEN** `finish-branch` SHALL 先同步 base,並確認 branch 的樹狀內容已完整落在 base 上,確認後才處置 branch/worktree 並移除 active_workflows row
- **AND** SHALL NOT 以 `git branch -d` 的祖先關係檢查作為該判準;squash 與 rebase merge 會改寫 commit,使該檢查對已合併與未合併的 branch 給出相同結果
- **AND** 該內容比對 SHALL 限縮於 branch 自身變更過的路徑;未限縮的全樹比對會在 base 於 PR 開啟期間前進時誤報,而 base 前進屬正常情形

#### Scenario: 兩處 `git branch -D` 的把關不對稱
- **WHEN** 有人主張為 Push + PR 收尾的 `git branch -D` 補上使用者確認,或反過來移除 Discard 的確認 gate
- **THEN** SHALL NOT 採納。兩者風險不同:Discard 銷毀的是未合併的成果,Push + PR 收尾在此之前已有內容比對把關
- **AND** 為每次例行清理加設確認會使該 gate 被學會忽略,而被學會忽略的 gate 比沒有 gate 更糟
