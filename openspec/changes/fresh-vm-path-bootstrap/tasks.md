## 1. 設定檔注入

- [x] 1.1 編輯 `.chezmoi.toml.tmpl` 在 `[interpreters.sh]` 區塊之前加入 `[scriptEnv]`，prepend `~/.local/bin` 到 PATH（用 `joinPath .chezmoi.homeDir ".local/bin"` 與 `env "PATH"`，注意 Windows 用 `;`、Unix 用 `:` 分隔）
- [x] 1.2 確認模板渲染後的 chezmoi.toml 在 Windows 上 PATH 開頭為 `C:\Users\<user>\.local\bin;<原 PATH>`，Linux/macOS 上為 `~/.local/bin:<原 PATH>`

## 2. setup-paths 腳本

- [x] 2.1 覆寫 `run_onchange_before_setup-paths.ps1.tmpl`（目前是 untracked `test` stub）為 Windows-only bootstrap 腳本（專案慣例 UTF-8 無 BOM、純 ASCII 內容避免 PS5 解碼問題）
- [x] 2.2 加入「確保 `~/.local/bin` 目錄存在」邏輯（`New-Item -ItemType Directory -Force` 若不存在）
- [x] 2.3 加入「jq.exe 不存在時下載」邏輯：版本字串與 `.chezmoiexternal.toml` 對齊（目前 `1.8.1`），用 `Invoke-WebRequest -Uri <URL> -OutFile <path>`；下載成功後驗證檔案大小 >0
- [x] 2.4 加入「User PATH 確保含 ~/.local/bin」邏輯：讀 `[Environment]::GetEnvironmentVariable("Path", "User")`，展開後比對 `~/.local/bin` 是否存在於任何 entry，不存在則 prepend 並寫回
- [x] 2.5 全程冪等：每一步先檢查 desired state，已達標時跳過實際操作；輸出 `Write-Host` 提示但不報錯

## 3. Spec 同步

- [x] 3.1 確認 `openspec/changes/fresh-vm-path-bootstrap/specs/chezmoi-structure/spec.md` 反映 `.chezmoi.toml.tmpl` 變更
- [x] 3.2 確認 `openspec/changes/fresh-vm-path-bootstrap/specs/tool-dependencies/spec.md` 反映 setup-paths 與 jq external 的新關係

## 4. 驗證

- [x] 4.1 `openspec validate fresh-vm-path-bootstrap --strict` 通過
- [x] 4.2 在當前機器執行 `chezmoi apply -v`：setup-paths 在內容變更後跑過一次（state dump 顯示已記錄）；modify_settings.json 全部 patched fields 仍在（effortLevel/skillListingBudgetFraction/permissions/hooks/env）
- [x] 4.3 `chezmoi execute-template < .chezmoi.toml.tmpl` 驗證 render 結果：`[scriptEnv]` 區塊 PATH 開頭為 `C:\Users\user\.local\bin;<原 PATH>`
- [x] 4.4 git diff 確認只動 `.chezmoi.toml.tmpl`（modified）+ `run_onchange_before_setup-paths.ps1.tmpl`（untracked stub 覆寫）+ openspec change 目錄；無誤觸他檔
- [x] 4.5 Wave 1 工具仍可呼叫：jq 1.8.1、starship 1.25.1、zellij 0.44.3、uv 0.11.14、ripgrep 15.1.0（`where.exe rg` 正確解析到 `~/.local/bin/rg.exe`；bash 內 `rg` alias 顯示 grep 為 Git Bash 既有怪癖，非本次 regression）

## 5. Archive 準備

- [ ] 5.1 Commit + `code:review-quick` 通過
- [ ] 5.2 `openspec archive fresh-vm-path-bootstrap` 後檢查 `openspec/specs/chezmoi-structure/spec.md` 與 `openspec/specs/tool-dependencies/spec.md` 是否正確合併（jq 那一條 Wave 1 scenario「後續 chezmoi 腳本仍能呼叫 jq」應已被新 scenario 取代或共存）
- [ ] 5.3 在 archive 完成後刪除 project memory `project_chezmoi_fresh_vm_path_bootstrap.md`，更新 `MEMORY.md` 待辦清單
