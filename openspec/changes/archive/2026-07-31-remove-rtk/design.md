## Context

RTK 目前橫跨六個 source 檔與三個引用點：binary 由 `.chezmoiexternal.toml` 下載、config
由 `.chezmoitemplates/rtk-config.toml` 單一來源分別餵給 Unix (`dot_config/rtk/`) 與
Windows (`run_onchange_install-05-rtk.ps1.tmpl`)、hook script 部署到
`~/.claude/hooks/rtk-rewrite.sh`、註冊則由 `modify_settings.json.sh.tmpl` 寫進
`settings.json` 的 `hooks.PreToolUse`。

關鍵約束是 chezmoi 的兩個非對稱性：

1. **刪除 source 不會刪除已部署的 target**（`home/.chezmoiremove` 開頭那兩行註解就是為此
   而寫）。`~/.claude/` 下的 `hooks/`、`commands/`、`skills/` 都不是 `exact_` 目錄，因為
   其中有非 chezmoi 管理的檔案。
2. **`modify_` 腳本是 patch 而非 render**。停止寫入某個欄位，等於讓既有機器上的舊值原地
   留存。同一支腳本的註解已經記下這條教訓（`CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS`
   與 `handoff-cleanup` 的 SessionEnd 條目都是靠 `del` / `map(select(...))` 主動清掉的）。

兩者相加產生一個具體的失敗模式：若只刪 hook script 與寫入那段 jq，已 apply 過的機器會留
下一筆指向**不存在檔案**的 `PreToolUse` 註冊，之後每一次 Bash tool call 都觸發失敗的 hook。

## Goals / Non-Goals

**Goals:**
- rtk 在所有已 apply 過的機器上隨下一次 `chezmoi apply` 完整消失——binary、config、hook
  script、`settings.json` 註冊四者皆然。
- 移除後 `settings.json` 的其餘 hook 註冊（含非 chezmoi 寫入者）完好無損。
- repo 中不再有 rtk 的殘留引用（docs、README、Renovate 註解）。

**Non-Goals:**
- 不評估替代的 token 壓縮方案。移除即結案；日後若要重新引入是另一個 change。
- 不清理 `rtk gain` 累積的統計資料本身（在 `~/AppData/Local/rtk` 內，隨該目錄一併刪）。
- 不處理從未 apply 過此 dotfiles 的機器。

## Decisions

### D1：`PreToolUse` 用外科式移除，不用 hard-assign 空陣列

<!-- evergreen-candidate -->
`modify_` 腳本退役一個欄位時，SHALL 主動刪除該值，而不是停止寫入它——`modify_` 是 patch
而非 render。刪除 SHALL 針對目標條目做外科式移除（`map(select(... | not))`），不得整體
覆寫該 key，因為同一個 key 可能有其他工具於 runtime 註冊的條目。

具體形狀直接沿用同檔案 SessionEnd 的既有寫法：

```jq
| .hooks.PreToolUse = (
    (.hooks.PreToolUse // [])
    | map(select(
        ((.hooks // []) | map(.command // "") | any(test("rtk-rewrite"))) | not
      ))
  )
| if (.hooks.PreToolUse | length) == 0 then .hooks |= del(.PreToolUse) else . end
```

**替代方案（否決）**：`.hooks |= del(.PreToolUse)` 一刀砍掉整個 key。目前 rtk 是唯一的
`PreToolUse` 條目，看似等價；但 plugin 或其他工具隨時可能在 runtime 註冊 `PreToolUse`，
一刀砍會靜默吃掉它們。外科式移除的成本只是多三行 jq。

### D2：`.chezmoiremove` 列出全部四類 target，不做 OS 條件判斷

新增條目：

```
.claude/hooks/rtk-rewrite.sh
.config/rtk
AppData/Roaming/rtk
AppData/Local/rtk
.local/bin/rtk
.local/bin/rtk.exe
.cache/rtk-hook-version-ok
```

`.chezmoiremove` 支援 template，但這裡刻意不用：移除一個在該 OS 上根本不存在的路徑是
no-op，加上 `{{ if eq .chezmoi.os ... }}` 只是讓檔案更難讀。

`.local/bin/rtk{,.exe}` 由 external 部署。即使 chezmoi 在 external 條目消失後會自行修剪
（未實測確認），明列一次的成本是零，而漏掉的成本是一顆躺在每台機器 PATH 上的孤兒
binary。**選擇明列**。

`AppData/Local/rtk` 與 `.cache/rtk-hook-version-ok` 是 rtk 的 runtime state，嚴格說不是
chezmoi 部署的 target。仍然列入，因為 `.chezmoiremove` 是這個 repo 唯一能跨機器傳播刪除
的機制，而放著不管就是永久殘留。

### D3：`docs/rtk.md` 整份刪除，不保留 retired 存根

決策已在 `git log` 與本 change 的 `openspec/changes/archive/` 記錄中留存，README 的工具表
與 `docs/claude-code.md` 的章節一併移除。保留一份「已移除」的存根只會讓讀者以為它還有
某種現役地位。

### D4：單次移除，不做分階段 deprecation

hook 一旦從 `settings.json` 拔掉，rtk binary 就完全 inert——它不是 shell alias，不會在
任何其他路徑被觸發。因此沒有理由分兩批放行。

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| `settings.json` 清理條文在所有機器 apply 完後就成為死碼，但無從得知何時安全刪除 | 接受。同檔案的 `handoff-cleanup` 清理已是同樣狀態；成本是幾行 jq，遠低於誤刪的代價 |
| 某台機器長期不 apply，rtk 繼續在該機器扭曲輸出 | 無技術解。此為 dotfiles 的固有性質，非本 change 引入 |
| hook script 被 `.chezmoiremove` 移除、但 `settings.json` patch 因故未生效 → 每次 Bash call 觸發失敗的 hook | 兩者在同一次 `chezmoi apply` 內完成；依專案慣例先在本機 apply 驗證，確認 `settings.json` 內無 `rtk` 字樣後才提交 |
| Renovate 已開的 rtk bump PR（若有）會變成孤兒 | 移除 `# renovate:` 註解後不再產生新的；既有的手動關閉 |
