## MODIFIED Requirements

### Requirement: 跨工具部署
七個自家流程/紀律 skills(`grill`、`tdd`、`diagnose`、`verify-done`、`worktree`、`finish-branch`、`coordinating-lines`)SHALL 以 chezmoi shared-body(`home/.chezmoitemplates/skills/<name>.md`)+ per-tool name-map wrapper 部署,Claude 與 Codex 共用同一份身體。

#### Scenario: chezmoi apply 後雙工具可用
- **WHEN** `chezmoi apply` 完成
- **THEN** `~/.claude/skills/<name>/SKILL.md` 與 `~/.codex/skills/<name>/SKILL.md` SHALL 存在且由同一份 shared body 渲染,skill 引用依各工具 name-map 呈現(Claude 用 namespaced 名稱、Codex 用 `$` sigil)

#### Scenario: 不再依賴 superpowers symlink
- **WHEN** 檢查 `~/.codex/skills/`
- **THEN** SHALL NOT 存在指向 Claude plugin cache 的 superpowers symlink,`install-superpowers-codex.sh` SHALL 不存在於 chezmoi source

## ADDED Requirements

### Requirement: coordinating-lines 協調者契約
`coordinating-lines` SHALL 定義**協調者**角色:自己不寫程式,產出是裁決、跨線事實、handoff。它 SHALL 明示自己是 wayfinder 的延伸,處理 wayfinder 排除的那半——多條線同時解票——並以對應表把既有載體對上 wayfinder 概念(map↔handoff、decision ticket↔線＋編號、fog↔待認領清單、blocking↔解鎖條件)。

skill 內文 SHALL 分兩層:**主體為平台中立的協調原則**,**附錄收平台／工具相依的機制**。分層判準 SHALL 為「換一個 repo、換一個 merge 平台、或換一個 agent kind 之後,這句話會不會靜默失效」——會的進附錄並標明前提,不會的留主體。

#### Scenario: 主體不綁定部署平台
- **WHEN** 讀者所在的 repo 其 merge 方式不是 ff + squash
- **THEN** 主體的排程規則 SHALL 仍然可讀且不誤導——凡依賴該設定的句子 SHALL 標明前提或位於附錄

#### Scenario: 不得指向 repo-scoped memory
- **WHEN** skill 內文要引用某條經驗的來源
- **THEN** SHALL NOT 以裸 slug 指向任一 repo-scoped memory;操作性事實 SHALL 內聯於 skill 內文本身

#### Scenario: agent 專屬機制走 name-map
- **WHEN** 內容只在特定 agent 成立(如 `/rename`、`-n`、`--remote-control` 等 Claude CLI 旗標)
- **THEN** SHALL 經 per-tool name-map 或 gap 字串呈現,渲染出來的 Codex 版 SHALL NOT 指向 Codex 不存在的旗標或 skill

#### Scenario: 來源軼事保留
- **WHEN** 內文含帶日期的實戰軼事(某日某線報了什麼數字、回收了哪個編號)
- **THEN** SHALL 保留於主體——軼事是時間戳記的事實,換平台不會使其為假,且為規則提供唯一無法從別處推導的證據
