## 1. 選擇邏輯（測試先行）

- [x] 1.1 新增 `tests/switch-pwsh-to-msi.Tests.ps1`（Pester）：用 AST 從 `home/dot_local/bin/switch-pwsh-to-msi.ps1` 取出 `Select-MsiRelease`，以 fixture 驗證 spec 的 4 個選擇 scenario（最新版沒有 MSI 改選舊版、7.6.10 優於 7.6.9、略過 prerelease/draft、全部沒有 MSI 回傳 `$null`）。此時測試 MUST 失敗（函式尚不存在）。
- [x] 1.2 在 helper 加入 `Select-MsiRelease`，讓 1.1 的測試通過。

## 2. 串進 helper 主流程

- [x] 2.1 把主流程的 `releases/latest` 改成 `releases?per_page=100`，呼叫 `Select-MsiRelease`；回傳 `$null` 時在任何移除動作之前 `throw`。
- [x] 2.2 選到的版本低於最新穩定版時，印出「最新穩定版 X 沒有 MSI，改裝 Y」。
- [x] 2.3 更新 helper 檔頭註解中「latest STABLE MSI」的描述。

## 3. 文件

- [x] 3.1 更新 `docs/powershell.md`：把「helper 在 7.7.0 發布後會失敗」那一條改成說明新行為（改選最新有 MSI 的穩定版）。

## 4. 驗證

- [x] 4.1 本機執行 `Invoke-Pester tests/switch-pwsh-to-msi.Tests.ps1`，全部通過。
- [x] 4.2 本機執行既有的 `tests/chezmoi-guard.Tests.ps1`，確認沒有退步。
- [x] 4.3 以非提權身分執行 helper，確認它仍在第一步拒絕並提示需要 admin（行為不變）。
- [x] 4.4 對真實的 GitHub API 只跑選擇邏輯（不安裝），確認選到 v7.6.10。
- [x] 4.5 `openspec validate fix-switch-pwsh-latest-msi`。
