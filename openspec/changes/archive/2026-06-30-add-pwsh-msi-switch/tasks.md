## 1. 偵測-警告 run script (B)

- [x] 1.1 新增 `home/run_warn-pwsh-msix.ps1.tmpl`，以 `{{ if eq .chezmoi.os "windows" }}` 包裹（非 Windows render 成空）
- [x] 1.2 偵測邏輯：`$PSHOME -like '*WindowsApps*'` OR `Get-AppxPackage Microsoft.PowerShell` 存在 → MSIX
- [x] 1.3 MSIX 時 `Write-Warning` 印出修復指引（指向 `~/.local/bin/switch-pwsh-to-msi.ps1`）；非 MSIX 靜默；MUST NOT 自動移除/安裝
- [x] 1.4 若腳本含非 ASCII，依 chezmoi-author 慣例加 UTF-8 BOM

## 2. MSI 切換 helper (C)

- [x] 2.1 新增 `home/dot_local/bin/switch-pwsh-to-msi.ps1`（純檔、ASCII-only 訊息）
- [x] 2.2 未提權則印指引並 `exit 1`（不自我 relaunch）
- [x] 2.3 移除 per-user 與 provisioned 的 `Microsoft.PowerShell` MSIX
- [x] 2.4 從 GitHub API `releases/latest` 取 `*-win-x64.msi` 下載
- [x] 2.5 驗 Authenticode：`Status -eq 'Valid'` 且 Subject 含 `Microsoft Corporation`，不符即中止不裝
- [x] 2.6 `msiexec /i <msi> /qn /norestart` 安裝；驗證 `C:\Program Files\PowerShell\7\pwsh.exe` 存在，失敗明確報錯
- [x] 2.7 `.chezmoiignore.tmpl` 非 Windows 忽略 `.local/bin/switch-pwsh-to-msi.ps1`

## 3. 文件 (A)

- [x] 3.1 README Windows bootstrap 補：winget 給的是 MSIX；要 MSI 版用 GitHub release 的 `PowerShell-<ver>-win-x64.msi`，並指向 switch helper
- [x] 3.2 `docs/powershell.md` 與之一致（MSIX vs MSI、helper 指引）

## 4. 驗證

- [x] 4.1 `chezmoi execute-template` render `run_warn-pwsh-msix.ps1.tmpl`（Windows）確認非空、語法正確；非 Windows render 成空
- [x] 4.2 偵測腳本在本機（已是 MSI pwsh）跑一次 → 應靜默通過（無 warning）
- [x] 4.3 helper 在未提權下執行 → 應印指引並 `exit 1`，不做任何破壞性動作
- [x] 4.4 `openspec validate add-pwsh-msi-switch --strict` 通過
