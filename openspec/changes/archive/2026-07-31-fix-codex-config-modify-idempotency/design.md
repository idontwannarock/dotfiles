## Context

`~/.codex/config.toml` 由兩支腳本產生，各自負責一個平台：

| 平台 | 檔案 | 機制 |
|---|---|---|
| Unix/macOS/WSL | `home/dot_codex/modify_config.toml` | chezmoi `modify_`：現有檔案由 stdin 進，新內容由 stdout 出 |
| Windows | `home/run_after_modify-codex-config.ps1.tmpl` | `run_after_` shim：`.toml` 副檔名在 Windows 無法透過 `[interpreters.*]` 派發，故改由 PowerShell 重寫整檔 |

兩者的職責相同：全域設定與 MCP server 清單由 repo 同步管理，`[projects.*]`（per-project trust 設定）是 per-machine 的，必須從現有檔案原地保留。

`modify_` 的契約使它成為一個迭代函數——輸出會在下一次 apply 成為輸入。因此它必須是不動點。目前不是。

### 缺陷

Unix 側的保留邏輯：

```awk
/^\[projects\./ { in_keep=1; print; next }
/^\[/           { in_keep=0 }
in_keep         { print }
```

`in_keep` 只有遇到下一個 `^\[` 才關閉。最後一個 `[projects.*]` 之後的下一個 `[` 就是 `[mcp_servers.openaiDeveloperDocs]`，所以夾在中間的空行**全部**被當成 projects 區塊的一部分印出。緊接著 MCP heredoc 自身又以一個空行開頭，於是每輪 N → N+1。

Windows 側 `$sections` 收集同樣的行、`$mcpConfig` 同樣以空行開頭，行為逐字對應。

實測（以本機檔案為輸入連跑兩輪）：159 → 160 → 161 行，每輪 diff 恰為 `146a147 >`。本機已累積 82 個空行。

## Goals / Non-Goals

**Goals:**

- 兩支腳本皆成為不動點，且對已累積雜訊的輸入單次收斂。
- 兩側行為維持逐字對應，修法在兩個 interpreter 中形狀相同。
- 把「不動點」與「雙源同步」寫成 spec 條文，使日後 verify 有可對照的依據。

**Non-Goals:**

- 不改變任何被同步的設定內容（model、profiles、MCP server 清單）。Windows 的 `cmd /c` 包裝是已標註的刻意平台差異，保留。
- 不改變 `[projects.*]` 的保留範圍語意——仍是「從 `[projects.` 起，到下一個 section header 止」。
- 不手動清理本機已累積的 82 個空行（見下方決策）。
- 不重寫這兩支腳本的整體結構。缺陷侷限在保留區塊的接縫，修法應同樣侷限。

## Decisions

### 1. 尾端空行由「取回時丟棄」處理，而非改寫 awk 的掃描邏輯

<!-- evergreen-candidate -->
問題出在**接縫**：腳本把三段（全域設定／保留區塊／MCP 區塊）接起來時，分隔用的空行由兩邊各出一個。凡是「切一段出來再接上別的東西」的邏輯，接縫處的空白歸屬都必須由單一方決定；讓被保留的內容自帶尾端空白，接縫就會每輪長一格。

修法統一為：**保留區塊一律修剪尾端空行，分隔符完全由腳本自己提供。**

Unix 側直接利用 POSIX 命令替換的既有行為——`$(...)` 定義上就會移除結果尾端的一串換行：

```bash
kept="$(echo "$existing" | awk '...原樣不動...')"
if [ -n "$kept" ]; then
    echo ""
    echo "$kept"
fi
```

awk 本身一個字都不用改。

**替代方案：在 awk 內緩衝空行，遇到下一個非空 `in_keep` 行才 flush。** 行為等價，但需要五行帶 `while (blanks-- > 0)` 的 awk，讀者得在腦中模擬狀態機才能確認正確性。命令替換的版本把同一件事交給一個有規範保證的既有行為，三行、無新狀態。選後者。

### 2. Windows 側以索引回退修剪，不用陣列切片

PowerShell 的對應修法：

```powershell
$lastIdx = $sections.Count - 1
while ($lastIdx -ge 0 -and $sections[$lastIdx] -match '^\s*$') { $lastIdx-- }
$sections = if ($lastIdx -ge 0) { $sections[0..$lastIdx] } else { @() }
```

**替代方案：`$sections = $sections[0..($sections.Count - 2)]` 迴圈。** 有陷阱：`Count` 為 1 時範圍變成 `0..-1`，而 PowerShell 的範圍運算子會把它展開成 `0, -1`，`-1` 又是「最後一個元素」的索引——結果不是清空陣列，而是複製出一個兩元素陣列，迴圈永不結束。索引回退法把邊界收在一個 `-ge 0` 判斷裡，沒有這個坑。

### 3. 不手動清理已累積的空行

<!-- evergreen-candidate -->
修正後的輸出形狀與輸入的尾端空行數無關，所以下一次 `chezmoi apply` 會直接把 82 個空行收斂掉。反過來說：如果一個「冪等性修正」還需要人工清一次現場，那多半代表修的是症狀而不是成因。**「不需要手動清理」本身就是這類修正是否修對的檢驗。**

這也給了現成的驗收條件——而且用**現在這份髒檔案**當測試輸入，比用乾淨檔案更有意義：它同時驗證了收斂與不動點兩件事。

### 4. 雙源同步升格為 spec 條文

`$codex-claude-parity` 這個 skill 早已不存在，字串卻還留在 Windows 側的 `instructions`，全 repo 只剩這一處。它能漂移這麼久，是因為「雙源必須同步」只寫在 `chezmoi-author` skill 的散文裡，沒有任何 spec 條文——verify 階段沒有可對照的東西。這次一併補上條文，並要求刻意的平台差異必須在原始碼標註理由，未標註者即視為漂移。

## Risks / Trade-offs

- **修剪誤刪 `[projects.*]` 區塊之間的空行** → 只丟棄整個保留結果**尾端**的空行；區塊之間的空行位在中段，不受影響。spec 的第三個 scenario 專門釘住這點，任務清單也以多區塊輸入實測。

- **命令替換連帶改變空字串的判斷** → 原碼以 `[ -n "$existing" ]` 判斷「有無現有檔案」，新碼改以 `[ -n "$kept" ]` 判斷「有無保留內容」。語意其實更準：舊碼在檔案存在但沒有任何 `[projects.*]` 時，仍會多印一個 `echo ""`，於是 MCP 區塊前出現兩個空行。新碼在這種情況下不印，輸出更乾淨——這是修正而非退步，但屬於行為改變，需在驗證時確認兩種輸入（有/無 projects 區塊）的輸出都正確。

- **Windows 側無法在本機驗證** → 這台是 WSL，PowerShell 修改只能靠靜態對照與邏輯推導。緩解：兩側修法刻意保持同一形狀，且 Windows 側的邊界陷阱（負索引）已在決策 2 中明確迴避；Unix 側的實測結果可作為兩者共同邏輯的證據。實機驗證留待下次在 Windows 機器 apply 時確認。

- **`echo "$existing"` 對含反斜線的內容可能有 interpreter 差異** → 沿用原碼寫法，不在本次擴大範圍。`[projects.*]` 的內容是路徑與 `trust_level`，Windows 路徑不經由這支腳本處理（Windows 走 PowerShell 那支），實務上不觸發。已知但不處理。

## Migration Plan

1. 改兩支腳本，在 WSL 本機以真實的 `~/.codex/config.toml`（含 82 個累積空行）驗證單次收斂與不動點。
2. `chezmoi apply` 後確認 `chezmoi diff` 對 `.codex/config.toml` 變乾淨，且 `[projects.*]` 內容一字未失。
3. Windows 機器下次 apply 時自動收斂，無需人工介入。

回退：兩支腳本都是純函數式的內容產生器，`git revert` 後下次 apply 即回到原行為（並重新開始累積空行）。無狀態遷移、無需清理。

## Open Questions

（無）
