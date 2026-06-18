# Design — Wave 12a: scoop CLI cleanup (jdtls leftover / lens / dos2unix)

## Context

Wave 12 拆兩輪。本輪（12a）是三個低風險項；7z（MSI + COM shell extension）與字型（.ttf 複製 + HKCU 註冊）留 12b。研究 spike 已完成：dos2unix win64 zip 為單檔 standalone（`bin/dos2unix.exe` 109KB，無 DLL，`--version` 可獨立執行）。

## Decisions

### D1 — dos2unix：archive-file 取單一 binary（jq/rg 模式）
zip 內為 `bin/{dos2unix,mac2unix,unix2dos,unix2mac}.exe` + `share/`。本 repo 僅用 `dos2unix`（install-03 修 plugin `.sh` 的 CRLF），故 `type = "archive-file"` 只取 `bin/dos2unix.exe` → `~/.local/bin/dos2unix.exe`，與 Wave 1 jq/rg 同模式。來源為 waterlander.net（dos2unix 官方 Windows build，非 GitHub）。

### D2 — dos2unix 的 prereq 排序
dos2unix 是 install-03（phase 3 run_onchange）的依賴，原由 install-prereqs（phase 1 run_onchange_before）以 `Ensure-ScoopTool` 安裝。改 external 後：chezmoi external 在「file 階段」（phase 2）部署 `~/.local/bin/dos2unix.exe`，早於 install-03（phase 3），故 install-03 可用。與既有 jq（external + `modify_settings.json.sh` 用）同樣的 bootstrap pattern，已驗證可行。移除 prereqs 的 dos2unix 安裝、留註解。

### D3 — lens / jdtls：soft-unmanage vs leftover 修正
- **jdtls**：install-03 的 `scoop install jdtls` 是 Wave 11 的真正 leftover（與 Wave 11 spec「任何 install 腳本 SHALL NOT scoop install jdtls」矛盾）→ 直接移除。
- **lens**：使用者要求「移出 scoop 安裝、不需 chezmoi 管理」。採 soft-unmanage（移除 install 呼叫、不主動 uninstall），比照 clink/dark/vimtutor 前例。移除後 containers 腳本不再有 active 安裝（docker/k8s 早遷走），化為歷史註解 stub；連帶移除已無用的 `Install-ScoopPackage` 函式與 scoop 前置檢查。

### D4 — migrate 範圍
Wave 12a migrate 只 `scoop uninstall dos2unix`（唯一真正改由 external 接手者）。**不**碰 lens（soft-unmanage）、**不**碰 jdtls（Wave 11 migrate 已處理 scoop 卸載；本輪只是移除會重裝它的 install 呼叫）。

## Risks

- dos2unix 來源是第三方站點（waterlander.net）非 GitHub release；URL pinning 仍可 reproducible，但站點可用性不如 GitHub。可接受（scoop 自己也用此來源）。
