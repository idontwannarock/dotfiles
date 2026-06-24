## 1. 移除 scoop GUI 清單

- [x] 1.1 刪除 `scoop/scoopfile.json`，並移除變空的 `scoop/` 目錄
- [x] 1.2 `.chezmoiignore.tmpl` 移除 `scoop` 行（不再有 source 需排除）

## 2. 改引用指向 gist

- [x] 2.1 `README.md` L39、L256：`scoop/scoopfile.json` 連結改指 gist URL
- [x] 2.2 `.chezmoitemplates/skills/chezmoi-author/windows.md` L9：改為「GUI app 清單維護於 gist，不在本 repo」

## 3. 清掉 no-op stub

- [x] 3.1 刪除 `run_onchange_before_install-prereqs.ps1.tmpl`

## 4. 驗證

- [x] 4.1 `git grep -i scoopfile`（排除 archive）無殘留指向 repo 內 scoopfile 的引用
- [x] 4.2 `chezmoi apply --dry-run`（或 diff）不因移除而報錯；確認 `scripts/scoop-interactive-update.ps1` 與 `scoopupdate` alias 仍在
- [x] 4.3 `openspec validate scoop-gui-to-gist` 通過
