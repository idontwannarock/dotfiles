## Context

Windows 上 chezmoi 以 `pwsh` 執行所有 `.ps1` run script（`[interpreters.ps1]` 已 pin，見既有 commit）。winget 的 `Microsoft.PowerShell` 為 `msix` 型，落 `WindowsApps`、靠可被關閉的 App Execution Alias 上 PATH、提權安裝 `0x80070005`；MSI 僅在 GitHub releases。使用者偏好 MSI 版但缺可重複工具。三道硬約束決定設計：**elevation**（MSI 裝需 admin，互動 UAC）、**破壞性**（移除唯一 pwsh 後若安裝失敗即缺殼）、**chicken-and-egg**（chezmoi 用 pwsh 跑 `.ps1`，故 `.ps1` 不能負責修 pwsh 本身）。

## Goals / Non-Goals

**Goals:**
- apply 期間以零風險方式提醒「pwsh 是 MSIX、建議切 MSI」。
- 提供可重複、版控、跨機器一致的手動切換工具，免得每台機器重走人工調查。
- 文件化 pwsh 前置條件與 MSI 取得方式。

**Non-Goals:**
- 不在 `chezmoi apply` 自動移除 MSIX 或安裝 MSI（踩上述三約束）。
- 不管理 pwsh 的後續版本升級（交由 helper 重跑或 `winget pin`，本變更不涉及）。
- 不支援 arm64（現有機器為 x64；未來可擴充）。

## Decisions

**D1. 偵測訊號 = `$PSHOME` 含 `WindowsApps` OR `Get-AppxPackage Microsoft.PowerShell` 存在。**
前者抓「當前 interpreter 就是 MSIX」，後者抓「MSI 已是 active 但仍殘留 MSIX」。兩者任一即提醒。替代（只看 `$PSHOME`）會漏掉並存殘留情境，故採 OR。

**D2. 偵測腳本用 plain `run_`（每次 apply 跑），不是 `run_once_`/`run_onchange_`。**
這是「持續提醒直到修正」的 nag：在壞狀態下每次 apply 都該提醒，修好後自動靜默（偵測通過）。`run_onchange_` 只在腳本內容變更時跑會 under-nag。偵測極廉價（一次 path 比對 + 一次 Appx 查詢），每次跑可接受。檔名 `run_warn-pwsh-msix.ps1.tmpl`，Windows-only（`{{ if eq .chezmoi.os "windows" }}` 包裹），非 Windows render 成空。

**D3. helper 要求「已提權」否則中止，不自我 relaunch。**
helper 做網路下載 + 驗簽 + 安裝 + 驗證，輸出需留在使用者的前景終端機看進度/錯誤。自我 `Start-Process -Verb RunAs` 會開新視窗、輸出隨關閉而消失。故要求使用者從提權終端機執行，未提權時印清楚指引並 `exit 1`。

**D4. MSI 來源 = GitHub API `releases/latest` 的 `*-win-x64.msi` asset。**
`releases/latest` 自動排除 prerelease（要穩定版），不 hardcode 版本（避免漂移）。解析 `assets[].browser_download_url` 取 `win-x64.msi`。

**D5. 安裝前驗 Authenticode：`Status -eq 'Valid'` 且 Subject 含 `Microsoft Corporation`。**
下載自網路的 installer 在 `msiexec` 前先驗簽，任一不符即中止不裝。對齊 repo 既有 gnupg 腳本「下載物先驗證」的慣例。

**D6. 編碼：helper 維持 ASCII-only（訊息用英文）。**
helper 可能在「pwsh 已被移除」的空窗期由 Windows PowerShell 5.1 執行；ASCII-only 可免去 5.1 無 BOM 時的 cp950 mojibake 風險（見 chezmoi-author windows.md）。偵測腳本 `run_warn-*` 在 chezmoi 的 pwsh 7 下執行（BOM-safe），若含非 ASCII 則依慣例加 UTF-8 BOM。

**D7. 部署位置 = `home/dot_local/bin/switch-pwsh-to-msi.ps1`（純檔，非 .tmpl）。**
`~/.local/bin` 已在 PATH（scriptEnv 前置），與既有 `corp-ssh-askpass.ps1` 同處。無需 template 變數，故不加 `.tmpl`。Windows-only 部署由 `.chezmoiignore` 控制（非 Windows 忽略 `.local/bin/switch-pwsh-to-msi.ps1`）。

## Risks / Trade-offs

- [helper 中途 MSI 安裝失敗 → pwsh 缺席] → helper 先移除 MSIX 再裝 MSI，失敗時明確報錯並指引手動補裝；使用者執行前本就應有 5.1 備援殼（文件提醒）。Windows PowerShell 5.1 永遠在，不會無殼。
- [每次 apply 的 warning 造成噪音] → 這是刻意 nag；修好即永久靜默，且不阻斷 apply。
- [GitHub API rate limit / 無網路] → helper 為人工觸發、即時可見錯誤；非 apply 路徑，不影響日常 apply。
- [winget 未來把 MSI 視為可「升級」回 MSIX] → 文件提醒可 `winget pin add`；本變更不自動處理升級。

## Migration Plan

純新增 + 文件補述，無破壞性 schema/行為變更。部署後：偵測腳本在既有 MSIX 機器下次 apply 即開始提醒；使用者自行擇時提權跑 helper 完成切換。Rollback：移除兩支新檔 + 還原文件即可，不留殘留狀態。

## Open Questions

無。（arm64、自動升級已列 Non-Goals。）
