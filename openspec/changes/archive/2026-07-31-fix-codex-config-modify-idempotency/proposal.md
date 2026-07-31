## Why

`dot_codex/modify_config.toml` 是 chezmoi `modify_` 腳本——目標檔內容 = 把現有檔案餵進 stdin、腳本吐出新內容。這類腳本必須是不動點（`f(f(x)) == f(x)`），否則每次 `chezmoi apply` 都會改變輸出。它不是：保留 `[projects.*]` 的 awk 把區塊尾端的空行一起吃進來，而下方 MCP heredoc 開頭又自帶一個空行，於是每 apply 一次就多一個空行。本機 `~/.codex/config.toml` 已累積 **82 個空行**（實測跑兩輪：159 → 160 → 161 行）。

TOML 對空行無感，所以功能沒壞——代價是 `chezmoi diff` 永遠不乾淨，真正的 drift 藏在雜訊裡認不出來。這次就是先把它誤判為「無關的既存 drift」而跳過，才回頭查出成因。

Windows 雙源 `run_after_modify-codex-config.ps1.tmpl` 是同一個形狀、同一個 bug。同時發現兩邊的 `instructions` 區塊已經漂移：Windows 側指向 `$codex-claude-parity`，而該 skill 在整個 source 裡已不存在（全 repo 只剩這一處字串）。

## What Changes

- **修 Unix 側冪等性**：`dot_codex/modify_config.toml` 保留 `[projects.*]` 的結果改以命令替換取回，其尾端空行一律丟棄，使輸出形狀與輸入的尾端空行數無關。
- **修 Windows 側冪等性**：`run_after_modify-codex-config.ps1.tmpl` 對 `$sections` 做相同的尾端空行修剪，維持與 Unix 側逐字對應的行為。
- **修雙源漂移**：Windows 側 `instructions` 的 `$codex-claude-parity` 改為 `$dev-workflow`，與 Unix 側一致。
- **不需要**另外清理已累積的 82 個空行：修正後輸出與輸入的尾端空行無關，下一次 apply 即自動收斂。若還需要手動清一次現場，代表修的是症狀而非成因。
- 新增兩條 spec 需求，補上既有 spec 沒涵蓋的兩個缺口（詳見下節）。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `chezmoi-script-conventions`: 新增兩條需求。
  - **「產生設定檔的腳本 SHALL 為不動點」**——現有 spec 裡所有「冪等」條文都是 install script 的守衛式語意（已安裝就跳過），與 `modify_*` 所需的不動點語意是不同的性質，目前無任何條文涵蓋，所以這個 bug 從來沒有規格能擋。
  - **「跨平台雙源實作 SHALL 保持同步」**——`modify_*` 在 Windows 因副檔名無法派發，必須由 `run_after_*.ps1.tmpl` shim 實作同一份邏輯。這條慣例目前只寫在 `chezmoi-author` skill，沒有 spec 條文，因此 verify 階段沒有可對照的依據；`$codex-claude-parity` 就是這樣漂移下來的。

## Impact

- `home/dot_codex/modify_config.toml`：保留區塊的取回方式（約 3 行）。
- `home/run_after_modify-codex-config.ps1.tmpl`：`$sections` 尾端修剪（約 4 行）＋ `instructions` 一字串。
- `openspec/specs/chezmoi-script-conventions/spec.md`：新增兩條需求。
- **執行面**：下次 `chezmoi apply` 會把本機 `~/.codex/config.toml` 那 82 個空行一次收斂掉。`[projects.*]` 的 per-machine 內容不受影響——修剪只作用於區塊尾端的空行。
- **不影響**：兩邊的全域設定、profiles、MCP server 清單皆不變（Windows 的 `cmd /c` 包裝是刻意的平台差異，保留）。
- **不影響** chezmoi 部署機制：無新增檔案、無新增 template、無 `.chezmoiremove` 需求（`run_*` 不部署，`modify_*` 改的是既有檔）。
- 無新增 runtime 相依：修法只用 POSIX 命令替換與 PowerShell 內建陣列操作。
