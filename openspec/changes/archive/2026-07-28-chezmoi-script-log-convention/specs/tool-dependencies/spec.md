## ADDED Requirements

### Requirement: Scoop 清理腳本（合併 Wave 2–7、11、12a）

`run_once_after_migrate-scoop-cleanup.ps1.tmpl` SHALL 在 Windows 上以單一「套件 → 移除理由」資料表驅動，卸載下列已改由 `.chezmoiexternal.toml` 或 OS 內建取代的 scoop 套件：

`kubectl`、`kubelogin`、`yt-dlp`、`hugo`、`hugo-extended`、`nexttrace`、`golangci-lint`、`gopass`、`curl`、`wget`、`clink`、`winget`、`winget-ps`、`docker`、`docker-compose`、`ffmpeg`、`vim`、`jdtls`、`dos2unix`。

卸載 SHALL 不論該套件原先是 dotfiles 安裝或使用者手動安裝。

腳本 SHALL 為冪等：某套件未由 scoop 安裝時該項視為 no-op；`Get-Command scoop` 回 not found 時印警告並整支 return。

腳本 SHALL NOT 卸載下列 soft-unmanaged 套件，無論其安裝狀態：`dark`、`vimtutor`、`lazydocker`、`lens`。

腳本 SHALL NOT 修改 User PATH（PATH 排序為 `run_once_after_migrate-scoop-to-external.ps1.tmpl` 的責任），且 SHALL NOT 觸及 `~/.local/bin`。

腳本 SHALL NOT 主動清理 gvim 右鍵選單 registry 項目。

僅 `jdtls` 一項 SHALL 額外清除殘留於 `~/scoop/shims` 的 shim（`jdtls`、`jdtls.exe`、`jdtls.cmd`、`jdtls.shim`、`jdtls.ps1`），且該清除 SHALL 於 scoop 未安裝 jdtls 時仍執行，以免過期 shim 與 `~/.local/bin/jdtls.cmd` 競爭。其餘套件 SHALL NOT 觸碰 `~/scoop/shims`。

資料表中每項的移除理由 SHALL 於執行時印出為該段落的目的。

#### Scenario: 已安裝的表列套件被卸載
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報已安裝（pkg 屬於上列清單）
- **THEN** 腳本執行 `scoop uninstall <pkg>`，scoop apps 目錄該套件被移除

#### Scenario: 表列套件未安裝時 no-op
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list <pkg>` 回報未安裝
- **THEN** 腳本不執行 `scoop uninstall`，繼續處理下一項

#### Scenario: scoop 未安裝時整支 skip
- **WHEN** chezmoi apply 在 Windows 執行，且 `Get-Command scoop` 回 not found
- **THEN** 腳本印警告訊息並 return，不嘗試任何 scoop 命令，且仍印出結束 banner

#### Scenario: soft-unmanaged 套件不被卸載
- **WHEN** chezmoi apply 在 Windows 執行，且 `dark`、`vimtutor`、`lazydocker`、`lens` 任一已由 scoop 安裝
- **THEN** 腳本 SHALL NOT 對其執行 `scoop uninstall`

#### Scenario: jdtls 殘留 shim 被清除（含未安裝情境）
- **WHEN** chezmoi apply 在 Windows 執行，且 `scoop list jdtls` 回報未安裝，但 `~/scoop/shims/jdtls.cmd` 存在
- **THEN** 腳本不執行 `scoop uninstall`，但仍移除該殘留 shim；`~/.local/bin/jdtls.cmd` 不受影響

#### Scenario: 非 jdtls 套件不觸碰 scoop shims
- **WHEN** 腳本處理 `vim`（已卸載完成）
- **THEN** 腳本 SHALL NOT 刪除 `~/scoop/shims` 下任何檔案

#### Scenario: User PATH 不被本腳本修改
- **WHEN** 清理腳本執行
- **THEN** User PATH 環境變數值維持不變

#### Scenario: 移除理由於 apply 輸出可見
- **WHEN** 腳本處理 `docker`
- **THEN** 輸出含一行說明其移除理由（CLI 已改由 chezmoi-external 於 `~/.local/bin/docker.exe` 提供）的段落目的

## REMOVED Requirements

### Requirement: Wave 2 一次性遷移腳本

**Reason**: `run_once_after_migrate-scoop-wave2.ps1.tmpl` 與 Wave 3–7、11、12a 的腳本控制流逐字相同，僅差套件清單一行。8 支腳本合併為單一資料表驅動的 `run_once_after_migrate-scoop-cleanup.ps1.tmpl`。

**Migration**: 本需求的所有約束（kubectl/kubelogin/yt-dlp/hugo/hugo-extended/nexttrace/golangci-lint 的卸載、冪等性、不動 User PATH）已完整併入新的「Scoop 清理腳本（合併 Wave 2–7、11、12a）」需求。

### Requirement: Wave 3 一次性遷移腳本

**Reason**: 同上，併入合併後的單一清理腳本。

**Migration**: gopass/curl/wget 的卸載（含「不論 dotfiles 安裝或使用者手動安裝皆卸載」語意）、scoop 未安裝時整支 skip、不動 User PATH，均已併入新需求。

### Requirement: Wave 4 一次性遷移腳本

**Reason**: 同上，併入合併後的單一清理腳本。

**Migration**: clink/winget/winget-ps 的卸載，以及 `dark`、`vimtutor` 的 soft-unmanaged 排除，均已併入新需求的清單與排除清單。

### Requirement: Wave 5 一次性遷移腳本

**Reason**: 同上，併入合併後的單一清理腳本。

**Migration**: docker/docker-compose 的卸載與 `lazydocker` 的 soft-unmanaged 排除已併入新需求。

### Requirement: Wave 6 一次性遷移腳本

**Reason**: 同上，併入合併後的單一清理腳本。

**Migration**: ffmpeg 的卸載與冪等性已併入新需求。

### Requirement: Wave 7 一次性遷移腳本

**Reason**: 同上，併入合併後的單一清理腳本。

**Migration**: vim 的卸載、以及「SHALL NOT 主動清理 gvim 右鍵選單 registry 項目」的約束，均已併入新需求。

### Requirement: Wave 11 一次性遷移腳本

**Reason**: 同上，併入合併後的單一清理腳本。jdtls 專屬的 shim 清理在新需求中以 per-package opt-in 表達，僅 jdtls 啟用。

**Migration**: jdtls 卸載、`~/scoop/shims/jdtls*` 殘留 shim 清除（含 scoop 未安裝 jdtls 時仍清）、不觸及 `~/.local/bin`、不動 User PATH，均已逐條併入新需求。

### Requirement: Wave 12a 一次性遷移腳本

**Reason**: 同上，併入合併後的單一清理腳本。

**Migration**: dos2unix 的卸載與 `lens` 的 soft-unmanage 排除已併入新需求。
