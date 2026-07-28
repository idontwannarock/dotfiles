## Why

`~/.claude/commands/ensure-openspec.md` 是未受 chezmoi 管理的孤兒,且不是靜態殘留 —— 它以 bare 名稱呼叫 `ensure-openspec.sh`,而 `~/.local/bin` 底下留有兩份四月舊副本(Linux 側缺 exec bit 被跳過,WSL PATH interop 併入的 Windows 側被命中),都不是 chezmoi 管理的正典 `~/.agent/bin/ensure-openspec.sh`。舊副本執行 `openspec init --tools claude`,會把 codex 與 antigravity 的 skill surface 靜默移除。該 command 另引用已不存在的 `opsx:new`。

同時,`install-03-claude-config` 的 cache 清理 `rm -rf … && echo "Removed …"` 每次 apply 都印出「已移除」,即使什麼都沒刪 —— `rm -rf` 對不存在的路徑仍 exit 0。這讓 apply 輸出無法用來判斷實際狀態。

`.ps1` 版則有多處 `claude … 2>&1 | Out-Null` 在 `$ErrorActionPreference = "Stop"` 下執行。`2>&1` 會把 native stderr 轉成 `ErrorRecord`,觸發 terminating `NativeCommandError`,使腳本中斷於 plugin 段,跳過後續的 cache 清理、hook 修復、MCP 註冊。同檔的 `marketplace add` 已用 `Continue`/`Stop` 三明治防護,其餘同形呼叫未防。

## What Changes

- `.chezmoiremove` 加入兩筆退役目標:`.claude/commands/ensure-openspec.md`(冗餘且會走到錯的腳本)與 `.local/bin/ensure-openspec.sh`(四月舊副本,正典在 `~/.agent/bin/`)
- `install-03-claude-config.sh.tmpl`:既有的 marketplace cache 清理改用 `[ -d ]` 前置判斷,訊息只在真的刪除時輸出
- `install-03-claude-config.ps1.tmpl`:為所有 `claude … 2>&1 | Out-Null` 呼叫補上 `Continue`/`Stop` 三明治,與同檔既有的 `marketplace add` 防護一致

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `claude-config`: 新增 install 腳本在嚴格錯誤模式下不得因 plugin 指令的 stderr 中斷的要求,以及 cache 清理訊息須反映實際動作的要求;並將退役 command 修剪的要求擴及跨 OS 的過時腳本副本

## Impact

- `home/.chezmoiremove`
- `home/run_onchange_install-03-claude-config.sh.tmpl`
- `home/run_onchange_install-03-claude-config.ps1.tmpl`
- `openspec/specs/claude-config/spec.md`

與 PR #31(`retire-superpowers-plugin-cleanup`)同時在途,兩者都改 `.chezmoiremove` 與同兩支腳本;本分支自 `main` 開出,先合併者不受影響,後者需 rebase。
