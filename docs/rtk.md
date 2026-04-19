# RTK — Token-reducing CLI proxy

[RTK (Rust Token Killer)](https://github.com/rtk-ai/rtk) 是一個 Rust binary，攔截 Claude Code 的 Bash tool call 並壓縮常見指令的輸出（git、npm、docker、kubectl 等），目標是省 60-90% 的 token。

此 dotfiles 只整合 Claude Code（不含 Codex），跨 Linux / macOS / Windows（Windows 原生 + Git Bash）。

## 檔案佈局

| 檔案 | 功能 |
|------|------|
| `.chezmoiexternal.toml` | 從 GitHub releases 下載 rtk binary 到 `~/.local/bin/rtk[.exe]`（依 OS/arch 選 asset）。版本 pin `0.36.0` |
| `.chezmoitemplates/rtk-config.toml` | 共用 blacklist TOML 片段（單一 source of truth） |
| `dot_config/rtk/config.toml.tmpl` | Unix 部署路徑（`~/.config/rtk/config.toml`） |
| `run_onchange_install-05-rtk.ps1.tmpl` | Windows 部署（rtk 在 Windows 只讀 `~/AppData/Roaming/rtk/config.toml`） |
| `dot_claude/hooks/executable_rtk-rewrite.sh` | 87 行 PreToolUse hook（RTK 官方模板 verbatim） |
| `dot_claude/modify_settings.json.sh.tmpl` | 擴充 jq patch：加 `hooks.PreToolUse[Bash]` 條目指向 hook script |

Windows 特殊處理由 `.chezmoiignore.tmpl` 排除 `.config/rtk/`。

## Hook 運作方式

Claude Code 發出 `Bash` tool call → PreToolUse hook fire → 執行 `bash ~/.claude/hooks/rtk-rewrite.sh` → 讀 stdin JSON 拿 `tool_input.command` → 呼叫 `rtk rewrite "<cmd>"`：

| `rtk rewrite` exit code | Hook 行為 |
|------------------------|----------|
| `0` + stdout | 把原指令改寫成 `rtk <cmd>`，自動 allow（Claude 無感執行） |
| `1` | 無改寫 — 原指令 passthrough |
| `2` | deny rule 觸發 — 讓 Claude Code 原生 deny 處理 |
| `3` + stdout | 有改寫但建議 prompt 使用者 —— 在 `acceptEdits` mode 會 fallback 到原指令（安全但不省 token） |

Hook 失敗永遠 exit 0，絕不擋 Claude 的指令流。

## Blacklist（exclude_commands）

`~/AppData/Roaming/rtk/config.toml`（Windows）或 `~/.config/rtk/config.toml`（Unix）的 `[hooks] exclude_commands` 欄位，以**第一個 token**比對要略過 rewrite 的指令。單一 source 在 `.chezmoitemplates/rtk-config.toml`。

當前黑名單 20 項（本機未安裝的工具）：
```
tsc, mypy, pytest, ruff, vitest, prisma, playwright,
eslint, prettier, next, rubocop, rspec, rake,
aws, dotnet, psql, wget, gt, golangci-lint, tree
```

**為何列黑名單**：RTK 0.36.0 有一個已知的 display layer bug — 當底層工具（例如 tsc）不存在時，RTK 的 summarizer 會把 npx fallback 的警告誤解析成「成功」訊息（例：`TypeScript compilation completed`），exit code 雖然正確但文字會誤導 Claude。黑名單讓這些指令 passthrough raw error，避免整合後的誤判。

裝了任何被黑名單的工具後，只要從 `.chezmoitemplates/rtk-config.toml` 移除該項、`chezmoi apply` 即可重新啟用 rewrite。

## Windows 相容性備忘

- **RTK 官方 `rtk init --global`**：Rust 源碼中 `run_default_mode` 是 `#[cfg(unix)]`，Windows 下會 fallback 到 legacy `--claude-md` 模式（只塞 prompt、沒 hook）。dotfiles **不用** `rtk init`，自己管理 hook。
- **.sh hook 在 Windows 會被 Claude Code 執行**：透過 settings.json 的 `CLAUDE_CODE_GIT_BASH_PATH` 指向 `bash.exe`。settings.json 的 `command` 要寫 `bash ~/.claude/hooks/rtk-rewrite.sh`（需要 `bash ` 前綴，不能只依賴 shebang）。
- **PowerShell exit code 傳遞**：我們的 hook 走 bash 所以無此問題。但若日後要寫 PS 版 hook，必須顯式 `exit $LASTEXITCODE`，否則 PS 會把 rtk 的 exit code 3（ask）壓成 1。
- **settings.json CRLF drift**：Claude Code 會以 CRLF 寫 settings.json，dotfiles 的 modify script 以 LF 寫。每次 `chezmoi apply` 會改回 LF，然後 Claude Code 下次啟動又改 CRLF。無害但 `chezmoi diff` 會持續顯示差異。

## 驗證 / 除錯

```bash
# 確認 rtk binary 可用
rtk --version   # expect: rtk 0.36.0

# 測試 rewrite 邏輯（不透過 hook）
rtk rewrite "git status"       # → "rtk git status", exit 0
rtk rewrite "tsc --version"    # → exit 1（blacklisted）
rtk rewrite "echo hi"          # → exit 1（無等價）

# 看 hook 是否被 Claude Code 觸發
# （在 ~/.claude/hooks/rtk-rewrite.sh 頂部加 `echo "$(date) $$" >> /tmp/rtk-hook.log`）

# 看累積的 token savings
rtk gain

# 看 config 有沒有被 rtk 讀取
rtk config | head -20
```

## 完全卸載

```bash
# 1. 從 dotfiles 移除
rm -f dot_claude/hooks/executable_rtk-rewrite.sh
rm -f run_onchange_install-05-rtk.ps1.tmpl
rm -rf dot_config/rtk/
rm -f .chezmoitemplates/rtk-config.toml
# 回退 .chezmoiexternal.toml、.chezmoiignore.tmpl、dot_claude/modify_settings.json.sh.tmpl

# 2. 套用
chezmoi apply

# 3. 清 runtime state（選擇性）
rm -rf ~/AppData/Local/rtk   # Windows
rm -rf ~/.cache/rtk-hook-version-ok
rm -f ~/.local/bin/rtk{,.exe}
```
