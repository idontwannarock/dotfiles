## ADDED Requirements

### Requirement: Windows bootstrap 不以 scoop 為 git 的必要安裝方式
README 的 Windows bootstrap 章節 SHALL 以 `winget install Git.Git` 安裝 git、`winget install twpayne.chezmoi` 安裝 chezmoi，且 SHALL NOT 將 scoop 描述為 git 的必要前提。scoop SHALL 僅以「選用（GUI app 參考清單）」呈現。README SHALL NOT 保留「git 一律透過 scoop、其他安裝方式會導致 script 執行失敗」之類的前提敘述（chezmoi 的 git-bash interpreter 改為偵測解析後已不成立，見 chezmoi-structure）。

#### Scenario: Windows bootstrap 用 winget 裝 git 與 chezmoi
- **WHEN** 使用者查閱 README 的 Windows bootstrap 章節
- **THEN** 可找到 `winget install Git.Git` 與 `winget install twpayne.chezmoi`，且無「git 必須經 scoop」之前提

#### Scenario: scoop 降為選用
- **WHEN** 使用者查閱 README
- **THEN** scoop 僅出現在「選用 / GUI app」脈絡，不在 chezmoi 運作的必要 bootstrap 步驟中
