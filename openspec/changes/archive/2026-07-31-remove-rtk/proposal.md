## Why

RTK 用輸出保真度換 token — 對 agent 而言這筆交易是虧的。2026-07-31 它把 `git status`
的輸出截斷後與下一段 `echo` 黏在一起，讓 agent 誤判 working tree 乾淨、並宣稱已合併的
工作尚未 commit；同一天 `wc -l` 對一個兩行的檔案回傳 `0`。失敗是**靜默**的：摘要過的輸出
看起來權威，沒有任何訊號提示該懷疑它，比沒有這個工具更糟。

省下的 token 也遠低於宣稱值。`docs/rtk.md` 自己記著：0.36.0 的 `rtk rewrite` 實際只改寫
約 10 個指令，20 項黑名單多數是 no-op，60-90% 的標題數字對應不到真實用量。

## What Changes

- 移除 rtk 的所有 source：hook script、Windows installer、config template 與其
  `.chezmoitemplates/` 片段、`.chezmoiexternal.toml` 的 binary 下載、`.chezmoiignore.tmpl`
  的 Windows 排除條目。
- `modify_settings.json.sh.tmpl` 的 `.hooks.PreToolUse` 由 hard-assign 改為**外科式移除**
  rtk 條目（比照同檔案既有的 `handoff-cleanup` SessionEnd 處理），陣列清空後 `del` 掉
  整個 key。單純刪掉寫入那段**不會**清掉已部署機器上的既有條目。
- `home/.chezmoiremove` 點名所有已部署 target：`.claude/hooks/rtk-rewrite.sh`、
  `.config/rtk`、`AppData/Roaming/rtk`、`.local/bin/rtk{,.exe}`。
- 刪除 `docs/rtk.md`，移除 `README.md` 工具表與 `docs/claude-code.md` 的 RTK 章節。

無 **BREAKING**：rtk 只影響 Bash tool 的輸出呈現，移除後指令回到 raw 輸出。

## Capabilities

### Modified Capabilities
- `claude-config`: 「退役項目要主動移除而非停止寫入」的條文，由既有的
  `.chezmoiremove` 點名（涵蓋 command / skill / 跨 OS 腳本副本）推廣到**由 `modify_`
  腳本寫進 `settings.json` 的 hook 註冊**——`modify_` 是 patch 而非 render，停止寫入
  留下的是指向已刪除 script 的死條目。

## Impact

| 類別 | 影響 |
|---|---|
| 刪除 | `home/dot_claude/hooks/executable_rtk-rewrite.sh`、`home/run_onchange_install-05-rtk.ps1.tmpl`、`home/dot_config/rtk/`、`home/.chezmoitemplates/rtk-config.toml`、`docs/rtk.md` |
| 修改 | `home/.chezmoiexternal.toml`、`home/.chezmoiignore.tmpl`、`home/dot_claude/modify_settings.json.sh.tmpl`、`home/.chezmoiremove`、`README.md`、`docs/claude-code.md` |
| spec | `claude-config` 一支 delta |
| Renovate | `.chezmoiexternal.toml` 中 `rtk-ai/rtk` 的 `# renovate:` 註解一併消失，不再產生 bump PR |
| 使用者機器 | 下次 `chezmoi apply` 移除 hook script、rtk config、rtk binary，並從 `settings.json` 拔掉 PreToolUse 註冊 |

**已確認不受影響**：`settings.json` 的其餘 hook（`UserPromptSubmit` 的 handoff-reminder、
`SessionStart` 的 claude-memory-seed）與 plugin 自帶的 hook 註冊皆不經此路徑。
