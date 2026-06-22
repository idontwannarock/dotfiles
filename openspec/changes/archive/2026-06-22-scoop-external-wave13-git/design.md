# Design — Wave 13: 把 git-bash interpreter 移出 scoop（偵測式，scope A）

## Context

scoop→chezmoi-external 系列的收尾。除了 git，所有工具都已離開 scoop。git 之所以是最後一個，因為它是**循環 bootstrap 依賴**：chezmoi 用 `[interpreters.sh]` 指定的 git-bash 跑每一個 `.sh`/`modify_*.sh` script，所以 bash 必須在 chezmoi 第一次 apply「之前」就存在——而 chezmoi-external 是 apply「期間」才落地。本 repo 自己的 jq bootstrap 註解（`.chezmoi.toml.tmpl:25-31`）已證明此 ordering 陷阱：`modify_settings.json`（target `.claude/…`）依字母序排在 `.local/…` external 之前。git 比 jq 更嚴重——連起始的 bash 都沒有。

結論：**git 無法由 chezmoi 管理（install 或 update），必須維持手動 prerequisite，只是改用非-scoop 方式。** scope A 只移除 chezmoi 對 scoop 的「依賴」，不卸載 scoop。

本機現況已確認：git bundle（scoop git == git-for-windows == PortableGit 同 layout）含 `bin/bash.exe` 與 `usr/bin/pinentry-w32.exe`；winget 為 OS 內建（不需 scoop）；chezmoi 目前由 scoop 裝。

## Decisions

### D1 — 偵測候選清單，而非 hardcode 單路徑、更非 `where bash`
**為何不用 PATH 搜尋（`where.exe bash` / chezmoi `lookPath`）**：interpreter pin 的存在本來就是為了「繞過 PATH」。`where bash` 的第一個命中幾乎都是錯的：
- `C:\Windows\System32\bash.exe`＝**WSL** launcher，無法處理 chezmoi 傳入的 Windows 暫存路徑（這正是 `windows.md` 記載的失敗）。
- git 的 `usr\bin\bash.exe`＝裸 bash，缺 MSYSTEM 設定，從非-MSYS parent（chezmoi/PowerShell）載入 coreutils DLL 會失敗；必須用 `bin\bash.exe` wrapper。
- scoop shim＝shim 非真 binary。

所以不是找「任一 bash」，而是找「一個 Git-for-Windows 安裝」，用它**已知正確**的 `bin\bash.exe`。採**有序候選清單**（每個候選＝一個已知安裝 root，以 `bin\bash.exe` 存在性驗證），第一個勝出。順序＝偏好：
1. `~/.local/opt/git/bin/bash.exe`（PortableGit）
2. `C:\Program Files\Git\bin\bash.exe`（winget / 官方）
3. `~/scoop/apps/git/current/bin/bash.exe`（scoop — 殿後，相容舊機）

非-scoop 在前 → 新安裝自動優先；scoop 殿後 → 舊機器不破壞。

### D2 — 兩處偵測，能力不同
偵測邏輯出現在兩個既有位置：
- **`.chezmoi.toml.tmpl`**（init 時 render）：template 只能 `stat`，故用上面 (1)(2)(3) 的 static 清單，first-existing 寫進 `[interpreters.sh]`。template **無法讀 registry**。
- **`run_onchange_before_patch-chezmoi-config.ps1.tmpl`**（每次 apply，self-heal）：PowerShell 有 registry/filesystem 能力，故用同 static 清單 **外加** `HKLM/HKCU\SOFTWARE\GitForWindows\InstallPath` probe（補捉非預設目錄的 winget/官方安裝；PortableGit/scoop 不寫此 key 故仍靠 static 路徑）。解析後若 config 的 interpreter 與偵測不符則改寫（self-heal）。其既有「scoop git bash 不存在就警告」的 guard，改成檢查偵測到的路徑。

兩者清單順序一致；PS 版多一個 registry 候選（插在 Program Files 之前或同位，因 InstallPath 即官方安裝實際位置）。

### D3 — 另外 2 處 functional refs 共用偵測結果
- `dot_claude/modify_settings.json.sh.tmpl`：`git_bash` arg 餵給 settings.json（Claude Code 的 git bash 設定）。改用偵測到的 bash 路徑（與 interpreter 同源）。此檔是 `.sh.tmpl`，可在 template 內以同 `stat` 清單算出路徑。
- `run_onchange_install-gnupg.ps1.tmpl`：`pinentry-w32.exe` 取自 git 的 `usr\bin`。改成 `<偵測 git root>\usr\bin\pinentry-w32.exe`（PS 內用同清單算出 git root）。

為避免三份 PowerShell/template 各自重抄清單，偵測順序以「**單一可讀的候選陣列**」實作於各檔頂部（PS：`$gitRoots = @(...)`；template：`list ...`），凍結在註解說明三來源。YAGNI：不抽成共用 fragment（template 與 PS 無法共用，且各檔只用一次）。

### D4 — git root vs git bash 的衍生
偵測「git root」（如 `C:\Program Files\Git`），其下 `bin\bash.exe`（interpreter / settings.json）與 `usr\bin\pinentry-w32.exe`（gnupg）由 root 衍生。候選驗證以 `bin\bash.exe` 存在為準（pinentry 在同 bundle 必同在，本機已驗證）。

### D5 — README / bootstrap
Windows bootstrap 改：`winget install Git.Git` → `winget install twpayne.chezmoi` → `chezmoi init`。移除「git 一律透過 scoop…其他方式會失敗」前提（偵測後已不成立）。scoop 降為「選用：GUI app」。`bootstrap-docs` spec line 8 已要求 winget git，本變更使 README 對齊。

### D6 — dos2unix 提示（瑣事）
`install-03:98` 的 `else` 分支（dos2unix 找不到時）提示文字由 `scoop install dos2unix` 改為「重跑 `chezmoi apply`（external 會補上 `~/.local/bin/dos2unix.exe`）」。純訊息，不改行為（該分支實務上不會觸發）。

### D7 — 本機遷移與驗證
本機現有 scoop git。步驟：`winget install Git.Git`（裝到 Program Files）→ `chezmoi init`（重 render interpreter，偵測應選 Program Files git，因清單 (2) 在 scoop (3) 之前）→ `chezmoi apply` 驗證走新 bash 正常（modify_settings、gnupg pinentry、`.sh` scripts 全綠）。scoop git 留著但不再被引用。**不** `scoop uninstall git`。

## Risks

- **循環 bootstrap**：git 仍是 prerequisite；偵測要求 git 在 `chezmoi init` 前已裝。README 明載。可接受（與今日「先 scoop install git」同性質，只是換 winget）。
- **`where bash` 陷阱**（見 D1）：絕不用 PATH 搜尋；清單只列已知正確的 `bin\bash.exe`。
- **template 無 registry**（見 D2）：`.chezmoi.toml.tmpl` 僅靠 static 清單；非預設目錄的 winget 安裝由 PS self-heal 的 registry probe 補捉（apply 時修正）。極端情況：init 當下若 git 裝在非預設目錄且 static 清單未命中 → interpreter 暫空，但首次 apply 的 patch-chezmoi-config（run_before）會以 registry probe 修好。預設目錄（Program Files）本就在 static 清單，不受影響。
- **遷移安全**：清單把 scoop 殿後，既有 scoop 機器偵測仍命中 scoop git → 不破壞、無 flag-day。本機裝 winget git 後自動改走非-scoop。
- **winget 首裝需 admin**（Program Files machine-wide）：一次性 bootstrap 步驟，可接受。若使用者偏好免 admin，可改 PortableGit 解到 `~/.local/opt/git`（清單 (1) 已支援），但本輪 README 以 winget 為主路徑。
