## Context

`scoop/scoopfile.json` 是手工 GUI app 參考清單：未被任何腳本消費（無 `scoop import/export`）、未被 chezmoi 部署（`.chezmoiignore` 第 9 行排除 `scoop`，且 `scoop/` 無 `dot_` 前綴）。使用者已在外部 gist 維護一份更完整的 `scoop export`（43 apps / 5 buckets）。`run_onchange_before_install-prereqs.ps1.tmpl` 經查為 no-op 死 stub（body 全註解，0 行非註解）。

## Goals / Non-Goals

**Goals:**
- 移除 repo 內雙頭維護的 scoop GUI 清單，改以連結 reference 外部 gist。
- 把 scoop 殘餘職責邊界明文化（僅互動更新腳本）。
- 清掉 no-op prereqs stub。

**Non-Goals:**
- 不移除 scoop 本身或互動更新腳本。
- 不清理偵測清單裡的 scoop back-compat fallback（那是相容舊機，無害）。
- 不整理 gist 內容（gist 由使用者維護，含已遷移工具屬其自由）。

## Decisions

- **刪除而非保留空 `scoop/`**：目錄變空即移除，並同步移除 `.chezmoiignore` 的 `scoop` 行（dead pattern）。
- **不需 `.chezmoiremove`**：scoopfile.json 從未部署到任何 home；prereqs 為 run 腳本、無部署產物。刪 source 即足夠。
- **reference 方式＝文件連結**：README + chezmoi-author windows.md 指向 gist URL，不做自動 `scoop import`（維持「手工清單」語意，符合使用者「頂多 reference」的意圖）。

## Risks / Trade-offs

- [gist 失聯/被刪 → 失去 GUI 清單參考] → 可接受；清單本為非關鍵參考資料，且使用者掌控 gist。
- [chezmoi-author windows.md 是部署到 skill 的模板] → 改 source fragment 即隨下次 apply 傳播；無破壞性。
