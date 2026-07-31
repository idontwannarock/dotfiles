## 1. 建立 feedback loop（先紅）

- [x] 1.1 把本機真實的 `~/.codex/config.toml`（已累積 82 個空行）複製一份到 scratchpad 當測試輸入 `dirty.toml`，另備一份只含全域設定＋單一 `[projects.*]`＋MCP 的乾淨輸入 `clean.toml`，以及一份完全沒有 `[projects.*]` 的輸入 `noproj.toml`
- [x] 1.2 寫一支 scratchpad 驗證腳本：對給定輸入連跑腳本兩輪，比較 `pass1` 與 `pass2`，不同即為 FAIL（不動點檢驗）；並回報 `pass1` 的總行數
- [x] 1.3 驗證：以修改前的 `home/dot_codex/modify_config.toml` 跑三個輸入，`dirty` 與 `clean` 皆 FAIL（每輪多一行）——確認 loop 真的會紅

## 2. Unix 側修正（blocked by #1）

- [x] 2.1 改 `home/dot_codex/modify_config.toml`：保留區塊改以 `kept="$(echo "$existing" | awk '...')"` 取回（awk 本體不動），條件由 `[ -n "$existing" ]` 改為 `[ -n "$kept" ]`，並加註解說明「尾端空行必須丟棄、分隔符由腳本單方提供」這個冪等性成因
- [x] 2.2 驗證：`dirty`、`clean`、`noproj` 三個輸入皆通過不動點檢驗（pass1 == pass2）
- [x] 2.3 驗證：`dirty` 單次執行即收斂——`pass1` 與以 `clean` 為輸入的結果，其 `[projects.*]` 到 `[mcp_servers` 之間的空行數相同（收斂到正規形式）
- [x] 2.4 驗證：`[projects.*]` 內容零遺失——比對修正前後輸出中所有 `[projects.` 開頭的行與其 `trust_level` 值，逐字相同；且多區塊之間的空行仍在
- [x] 2.5 驗證：`noproj` 輸入的輸出中，`web_search = "live"` 與 `[mcp_servers.openaiDeveloperDocs]` 之間恰為一個空行（確認 design 決策 3 提到的行為改變如預期）

## 3. Windows 側鏡像修正（blocked by #2）

- [x] 3.1 改 `home/run_after_modify-codex-config.ps1.tmpl`：在 `$sections` 收集完成後、`$keptSections` 組裝之前，以索引回退法修剪尾端空行（依 design 決策 2，不用 `0..($Count-2)` 切片），並加註解說明成因與負索引陷阱
- [x] 3.2 修雙源漂移：`instructions` 區塊的 `$codex-claude-parity` 改為 `$dev-workflow`
- [x] 3.3 驗證：`grep -rn 'codex-claude-parity' home/` 無殘留
- [x] 3.4 驗證：逐行比對兩支腳本的全域設定與 `instructions` 區段，除已標註的平台差異（`cmd /c` 包裝）外逐字相同
- [x] 3.5 驗證：`chezmoi execute-template < home/run_after_modify-codex-config.ps1.tmpl` 在 Linux 上渲染為空（`{{- if eq .chezmoi.os "windows" -}}` 守衛），確認未破壞 template 語法
- [x] 3.6 驗證：以 PowerShell 語意人工走查修剪迴圈的三個邊界——`$sections` 全為空行、只有一個元素、無空行——確認皆不進入無窮迴圈且結果正確

## 4. 部署與實機驗證（blocked by #3）

- [x] 4.1 `chezmoi apply` 限定 `~/.codex/config.toml` 範圍套用（避免牽動無關的 `run_*` 腳本）
- [x] 4.2 驗證：套用後 `chezmoi diff` 對 `.codex/config.toml` 無輸出
- [x] 4.3 驗證：再跑一次 `chezmoi apply`，`chezmoi diff` 仍無輸出（實機上的不動點確認）
- [x] 4.4 驗證：套用後的 `~/.codex/config.toml` 中，9 個 `[projects.*]` 區塊與其 `trust_level` 全數存在且值未變
- [x] 4.5 驗證：檔案為合法 TOML（以 Codex CLI 能正常啟動、或以任一 TOML parser 解析確認）

## 5. 收尾（blocked by #4）

- [ ] 5.1 `openspec validate --change fix-codex-config-modify-idempotency` 通過
- [ ] 5.2 依 `chezmoi-author` skill 的 Authoring Checklist 逐項複查（特別是第 2 項：`modify_*` 仍不含任何 log banner；第 6 項：平台對應檔已同步）
- [ ] 5.3 `openspec-sync-specs`：評估 design.md 兩個 `<!-- evergreen-candidate -->`（接縫空白歸屬、不需手動清理即修對的檢驗）是否通過晉升閘門，通過則寫入 `context/`
