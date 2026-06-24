## Why

跨平台工具已全數移出 scoop（Wave 1–13 + interactive git）。scoop 在本 repo 的殘餘職責應收斂到「只負責不經 chezmoi 跨平台管理的部分」。目前 `scoop/scoopfile.json` 是一份手工 GUI app 參考清單，但它從不被任何腳本消費、也不被 chezmoi 部署，且使用者已在外部 gist 維護一份更完整的 `scoop export`。把它留在 repo 只會雙頭維護、易過期。

## What Changes

- **移除 `scoop/scoopfile.json`**（連同變空的 `scoop/` 目錄）。GUI app 清單改由外部 gist 維護，repo 僅以連結 reference。
- **`.chezmoiignore.tmpl` 移除 `scoop` 行**：不再有 `scoop/` source 需要排除部署。
- **更新引用指向 gist**：`README.md`（兩處）與 `.chezmoitemplates/skills/chezmoi-author/windows.md` 原本指向 `scoop/scoopfile.json` 的文字改指 gist。
- **移除 `run_onchange_before_install-prereqs.ps1.tmpl`**：已是 no-op 死 stub（body 全註解，jq/dos2unix 早改由 `.chezmoiexternal.toml` 提供），與 scoop / 更新腳本無關。
- **保留** `scripts/scoop-interactive-update.ps1` + `scoopupdate` alias + `docs/user-scripts.md`：scoop 在本 repo 唯一保留的職責是這支互動更新腳本。

## Capabilities

### New Capabilities
<!-- 無 -->

### Modified Capabilities
- `tool-dependencies`: 新增需求——明文界定 scoop 在本 repo 的殘餘職責邊界（GUI app 清單外置於 gist、不在 repo；repo 僅保留互動更新腳本），使「為何 repo 內沒有 scoop app 清單」有據可循。

## Impact

- **repo**：刪除 `scoop/scoopfile.json`、`run_onchange_before_install-prereqs.ps1.tmpl`；改 `.chezmoiignore.tmpl`、`README.md`、chezmoi-author skill 的 `windows.md`；`tool-dependencies` spec delta。
- **部署**：無。scoopfile.json 從未部署（`.chezmoiignore` 排除）；prereqs 為 no-op；故**不需** `.chezmoiremove`。
- **外部**：GUI app 清單的 source of truth 移至 gist <https://gist.github.com/idontwannarock/cef42b856b878e718a2e402eb8e5d7e1>。
