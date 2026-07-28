## 1. 修剪孤兒

- [x] 1.1 `home/.chezmoiremove` 加入 `.claude/commands/ensure-openspec.md` 與 `.local/bin/ensure-openspec.sh`，附註說明正典位置與 WSL PATH interop 的命中問題
- [x] 1.2 驗證:`chezmoi apply` 後 `~/.claude/commands/ensure-openspec.md` 不存在;`command -v ensure-openspec.sh` 不再命中 Windows 側副本（該路徑須待 Windows 機器 apply 才實際移除，本機記錄現況）

## 2. cache 清理訊息

- [x] 2.1 `home/run_onchange_install-03-claude-config.sh.tmpl`:既有 marketplace cache 清理改用 `[ -d ]` 前置判斷，與本檔另一處清理及 `.ps1` 的 `Test-Path` 語義一致
- [x] 2.2 驗證:渲染後 `bash -n` 通過;實際執行時該路徑不存在則不輸出 "Removed marketplace superpowers"

## 3. PowerShell stderr guard

- [x] 3.1 `home/run_onchange_install-03-claude-config.ps1.tmpl`:為所有 `claude … 2>&1 | Out-Null` 呼叫補上 `Continue`/`Stop` 三明治（slack / episodic-memory / elements-of-style / explanatory-output-style 的 install，learning-output-style 的 uninstall）
- [x] 3.2 檢查同檔其他以 `2>&1` 重導向的 native 呼叫是否有相同暴露，一併處理或明確記錄為不適用
- [x] 3.3 驗證(受限):本機無 pwsh，僅能做人工比對與 template OS 守衛檢查;實際執行待 Windows apply

## 4. 驗收

- [x] 4.1 `chezmoi diff` 確認僅預期變更
- [x] 4.2 `chezmoi apply` exit 0，install-03 完整跑完且無假陽性訊息
- [x] 4.3 `openspec validate prune-ensure-openspec-orphans --strict` 通過
- [x] 4.4 確認 `dev-workflow` 的 openspec 初始化路徑仍可用（`~/.agent/bin/ensure-openspec.sh` 未受影響）
