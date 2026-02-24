## Context

Shell 設定檔目前以單一檔案搭配 chezmoi template 條件部署。`.bashrc` 已是 `.tmpl`，但 `.shell_common` 和 `.zshrc` 是純文字檔。所有平台邏輯混在同一檔案中，且 `.gitattributes` 無法對不同平台的內容設定不同 EOL。

## Goals / Non-Goals

**Goals:**
- 每個平台的 shell 設定獨立成檔，避免不相容語法交叉汙染
- 透過 `.gitattributes` 對 template 片段強制 LF
- `.shell_common` 保留共用核心（base），各平台可獨立擴充
- 部署結果與重構前完全一致

**Non-Goals:**
- 不改變 shell 設定的實際功能或行為
- 不新增尚未存在的平台專屬設定內容
- 不處理 PowerShell profile（已有獨立管理機制）

## Decisions

### D1: 使用 `.chezmoitemplates/` + `template` 而非條件區塊

**選擇**：將平台專屬內容放在 `.chezmoitemplates/` 目錄，入口 `.tmpl` 檔用 Go 的 `{{ template "name" . }}` 選擇對應片段。chezmoi 的 `include` 函式只接受 1 個參數且從 source 根目錄讀取，不適用於 `.chezmoitemplates/`；`template` 函式則自動從 `.chezmoitemplates/` 載入並傳遞 template data。

**替代方案**：在單一 `.tmpl` 中用 `{{ if eq .chezmoi.os "..." }}` 條件區塊。

**理由**：分離成獨立檔案後，可各自設定 EOL、獨立 review、避免語法交叉。

### D2: 目錄結構按「檔案 → 平台」分組

**選擇**：`.chezmoitemplates/bashrc/windows`、`.chezmoitemplates/bashrc/linux` 等。

**替代方案**：按平台分組（`windows/bashrc`）或扁平命名（`bashrc-windows`）。

**理由**：同一設定檔的各平台版本放在一起，方便比較差異。

### D3: `.shell_common` 採 base + 平台擴充模式

**選擇**：`shell-common/base` 放共用邏輯，各平台片段用 `{{ template "shell-common/base" . }}` 引入再加上平台專屬內容。

**替代方案**：完全獨立的三份 `.shell_common`。

**理由**：目前共用邏輯佔 100%，完全複製會造成維護負擔。

### D4: 入口 `.tmpl` 對不支援的平台輸出空內容

**選擇**：`dot_bashrc.tmpl` 在 macOS 上渲染為空（chezmoi 不部署空內容），搭配 `.chezmoiignore.tmpl` 作為雙重保護。

**理由**：Template 層和 ignore 層雙重控制，降低誤部署風險。

## Risks / Trade-offs

- **新增間接層**：入口檔不再直接包含設定內容，需跳到 `.chezmoitemplates/` 查看。→ 目錄結構清晰且按檔案分組，可快速定位。
- **chezmoi `include` vs `template`**：chezmoi 的 `include` 只接受 1 個參數且從 source 根目錄讀取，不適用於 `.chezmoitemplates/`。改用 Go 的 `{{ template "name" . }}` 函式，自動從 `.chezmoitemplates/` 載入並傳遞 template data（含 `.isWSL` 等自訂變數）。
