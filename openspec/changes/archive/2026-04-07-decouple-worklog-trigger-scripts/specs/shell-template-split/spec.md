## MODIFIED Requirements

### Requirement: shell-common 平台片段 include base
每個平台的 `shell-common/{platform}` 片段 SHALL 透過 `{{ template "shell-common/base" . }}` 引入共用核心，再附加平台專屬設定。

#### Scenario: Windows shell-common 包含 base 內容
- **WHEN** 渲染 `shell-common/windows`
- **THEN** 輸出包含 `shell-common/base` 的完整內容

#### Scenario: 各平台 shell-common 輸出包含 base
- **WHEN** 渲染任一平台的 `shell-common/{platform}`
- **THEN** 輸出 MUST 包含 `createnewlog` 函式定義與 `_dotfiles_check_update` 函式
