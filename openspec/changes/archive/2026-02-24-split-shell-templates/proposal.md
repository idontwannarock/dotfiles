## Why

Shell 設定檔（`.bashrc`、`.shell_common`、`.zshrc`）目前以單一檔案部署到所有平台，靠 template 條件和 `.chezmoiignore` 控制。這導致兩個問題：不同平台的邏輯混在同一個檔案中，容易引入不相容語法；且無法透過 `.gitattributes` 對不同平台的片段設定各自的 EOL。

## What Changes

- 建立 `.chezmoitemplates/` 目錄結構，將 shell 設定按檔案和平台分離為獨立片段
- 將現有 `dot_bashrc.tmpl` 重構為入口檔，依 OS `include` 對應的 template 片段
- 將現有 `dot_shell_common` 改為 `dot_shell_common.tmpl`，拆出共用 base 和平台擴充片段
- 將現有 `dot_zshrc` 改為 `dot_zshrc.tmpl`，拆出 macOS 專用片段
- 更新 `.chezmoiignore.tmpl` 配合新架構
- 新增 `.gitattributes` 規則，強制 `.chezmoitemplates/` 使用 LF

## Capabilities

### New Capabilities
- `shell-template-split`: 將 shell 設定檔拆分至 `.chezmoitemplates/` 按平台管理，支援獨立 EOL 控制

### Modified Capabilities

(無既有 spec 受影響)

## Impact

- 檔案結構變更：新增 `.chezmoitemplates/` 目錄及 7 個 template 片段
- 既有檔案重新命名：`dot_shell_common` → `dot_shell_common.tmpl`、`dot_zshrc` → `dot_zshrc.tmpl`
- `.chezmoiignore.tmpl` 規則調整
- `.gitattributes` 新增 EOL 規則
- 部署結果不變：各平台最終取得的 `~/.bashrc`、`~/.shell_common`、`~/.zshrc` 內容與目前相同
