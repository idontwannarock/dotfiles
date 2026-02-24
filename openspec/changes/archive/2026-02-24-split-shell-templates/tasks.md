## 1. 建立 .chezmoitemplates 目錄結構

- [x] 1.1 建立 `.chezmoitemplates/bashrc/`、`.chezmoitemplates/shell-common/`、`.chezmoitemplates/zshrc/` 目錄
- [x] 1.2 建立 `shell-common/base`：從現有 `dot_shell_common` 搬入共用內容
- [x] 1.3 建立 `shell-common/windows`、`shell-common/linux`、`shell-common/darwin`：各自 include base
- [x] 1.4 建立 `bashrc/windows`：從現有 `dot_bashrc.tmpl` 提取非 WSL 部分
- [x] 1.5 建立 `bashrc/linux`：從現有 `dot_bashrc.tmpl` 提取完整內容（含 WSL 條件區塊）
- [x] 1.6 建立 `zshrc/darwin`：從現有 `dot_zshrc` 搬入完整內容

## 2. 重構入口檔

- [x] 2.1 改寫 `dot_bashrc.tmpl`：依 OS include `bashrc/windows` 或 `bashrc/linux`
- [x] 2.2 將 `dot_shell_common` 重新命名為 `dot_shell_common.tmpl`，改寫為依 OS include 對應片段
- [x] 2.3 將 `dot_zshrc` 重新命名為 `dot_zshrc.tmpl`，改寫為 include `zshrc/darwin`

## 3. 更新忽略規則與 EOL 設定

- [x] 3.1 更新 `.chezmoiignore.tmpl`：macOS 忽略 `.bashrc`、非 macOS 忽略 `.zshrc`、`.shell_common` 全平台部署
- [x] 3.2 更新 `.gitattributes`：`.chezmoitemplates/**` 強制 `text eol=lf`

## 4. 驗證

- [x] 4.1 執行 `chezmoi diff` 確認 Windows 上部署結果無變化
- [x] 4.2 執行 `chezmoi managed` 確認 Windows 上不再管理 `.zshrc`，仍管理 `.bashrc` 和 `.shell_common`
