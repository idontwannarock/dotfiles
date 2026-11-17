## Why

`switch-pwsh-to-msi.ps1` 從 GitHub 的 `releases/latest` 找 MSI。從 7.7.0 起，官方不再提供 MSI（[公告](https://devblogs.microsoft.com/powershell/powershell-msi-deprecation/)）；v7.7.0 只有 zip 和 `.msixbundle`。`releases/latest` 現在就是 7.7.0，所以 helper 會報 `No win-x64 MSI asset` 並結束，在 MSIX 機器上完全無法切換。7.6 是 LTS，官方仍為它提供 MSI（目前最新是 v7.6.10）。

## What Changes

- helper 改成列出 PowerShell releases，選出「穩定版（非 prerelease、非 draft）且含 `win-x64.msi` asset」之中版本號最高的一個，下載該 MSI。
- 其餘步驟不變：提權檢查、Authenticode 驗證、`msiexec` 安裝、移除 MSIX、驗證路徑。
- 當選到的版本低於最新穩定版時（例如選了 7.6.10，但最新是 7.7.0），helper 印一行說明：最新版沒有 MSI，所以改裝哪一個版本。
- `docs/powershell.md`：更新「helper 在 7.7.0 後會失敗」那一條，改成說明新行為。

## Capabilities

### New Capabilities

無。

### Modified Capabilities

- `pwsh-msi-provisioning`：helper 取得 MSI 的規則，從「最新穩定版的 MSI」改為「最新一個有 MSI 的穩定版的 MSI」。

## Impact

- 修改：`home/dot_local/bin/switch-pwsh-to-msi.ps1`、`docs/powershell.md`。
- 規格：`openspec/specs/pwsh-msi-provisioning/spec.md` 的第 2 個 requirement 更新（經由 delta spec）。
- 平台：Windows-only，與原本相同。
- 風險：helper 需要連 GitHub API。未登入的 API 有每小時 60 次的限制，一次手動執行遠低於此限制。
