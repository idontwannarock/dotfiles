## MODIFIED Requirements

### Requirement: 跨工具部署
六個自家流程/紀律 skills(`grill`、`tdd`、`diagnose`、`verify-done`、`worktree`、`finish-branch`)SHALL 以 chezmoi shared-body(`home/.chezmoitemplates/skills/<name>.md`)+ per-tool name-map wrapper 部署,Claude 與 Codex 共用同一份身體。

#### Scenario: chezmoi apply 後雙工具可用
- **WHEN** `chezmoi apply` 完成
- **THEN** `~/.claude/skills/<name>/SKILL.md` 與 `~/.codex/skills/<name>/SKILL.md` SHALL 存在且由同一份 shared body 渲染,skill 引用依各工具 name-map 呈現(Claude 用 namespaced 名稱、Codex 用 `$` sigil)

#### Scenario: 不再依賴 superpowers symlink
- **WHEN** 檢查 `~/.codex/skills/`
- **THEN** SHALL NOT 存在指向 Claude plugin cache 的 superpowers symlink,`install-superpowers-codex.sh` SHALL 不存在於 chezmoi source

#### Scenario: 已退役的 coordinate 不留部署殘骸
- **WHEN** 在任何曾部署過 `coordinate` 的機器上執行 `chezmoi apply`
- **THEN** `~/.claude/skills/coordinate` 與 `~/.codex/skills/coordinate` SHALL 被移除——兩個路徑 SHALL 列在 `home/.chezmoiremove`,因為只刪 source 只會讓 chezmoi 停止管理,已部署的副本會留下

## REMOVED Requirements

### Requirement: coordinate 協調者契約
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 派線時關閉線的直接發問管道
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 證據的資格
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 決策地圖的格子與寫入權
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 結論重驗的方向
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 共寫資源不限於檔案
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 收尾要問「還有什麼只有你知道」
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 工具回報成功不等於做了事
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 誰有資格說這句話
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 輸入框判斷之前的機械檢查
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 覆核者的資格
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 守衛存在但守著錯的東西
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 傳訊管道分兩層
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 線間訊息的載體
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 狀態條件不得寫成時序條件
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 收尾訊號要能接受「不適用」
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 承重規則置頂
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 接班協調者必須驗自己的發問能力
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 角色不在 argv 裡
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 命名三層各自獨立
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 裁決契約
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 負面條目貼在正面規則旁
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 定址名要艦隊限定
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 前綴與 cwd 是兩道正交檢查
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 艦隊名冊
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 交接的啟動形狀不得改變
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 艦隊產物的落點
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 資源池不得共用
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate map 的層級
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 位置指涉要有守衛
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 「沒有淘汰機制」的論證要結構性
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 守衛要有一層斷言自己輸出的檢查
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

### Requirement: coordinate 多直譯器覆蓋要驗證 harness 真的換了
**Reason**: `coordinate` skill 已退役——使用者認為它用處不大。
**Migration**: 無替代。需要多條平行線時,各線各自跑 `dev-workflow`;交接用 `handoff`。

