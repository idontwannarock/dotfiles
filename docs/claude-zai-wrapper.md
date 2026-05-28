# claude-zai Wrapper

讓 Claude Code 切換到 [z.ai](https://docs.z.ai/) 的 Anthropic-compatible endpoint，
跑 GLM 系列 model 而不是 Anthropic 原生。設計成 wrapper 函式，**不污染** `claude` 主指令——
平常工作維持 Anthropic，需要試 GLM 時打 `claude-zai`。

## 目前狀態

| 項目 | 狀態 |
|------|------|
| Phase 1（Windows PS 7 本機部署） | ✅ 已啟用 |
| Phase 3a（WSL bash + WSLENV propagation） | ✅ 已啟用 |
| Phase 2（chezmoi 管理 + gopass 存 key） | ⏳ 規劃中 |
| Phase 3b（macOS zsh / 純 Linux 機器） | ⏳ 規劃中 |

整套採「**本機部署、不進 chezmoi source**」做法，方便快速試味道；確認長期要用後再走 Phase 2 統一搬進 chezmoi。

## 部署位置

| 路徑 | 平台 | 用途 |
|------|------|------|
| `~/Documents/PowerShell/profile.d/25-claude-zai.ps1` | Windows | PS 7 wrapper 函式定義（profile loader 自動 source） |
| `~/claude-zai.ps1` | Windows | 原始 scratch 檔（可砍） |
| `HKCU\Environment\ZAI_API_KEY` | Windows | z.ai API key（user-level env var） |
| `HKCU\Environment\WSLENV` | Windows | 含 `ZAI_API_KEY/u`，Windows→WSL propagation |
| `~/.bashrc.local`（WSL Ubuntu） | WSL | bash wrapper 函式定義（在 zellij 區塊之後） |

> 兩端 wrapper 都在使用者目錄底下，不在 `D:\ws\github\dotfiles\` 內。Windows 端 `chezmoi diff` 會顯示 `profile.d/25-claude-zai.ps1` 為 extra file（不會被 apply 砍）。WSL 端 `.bashrc.local` 本來就是 dotfiles 預留的 chezmoi-bypass 擴充點，完全不衝突。

## 一次性設定

### Windows PS 7

```powershell
# 設 z.ai API key（落到 registry HKCU\Environment）
[Environment]::SetEnvironmentVariable('ZAI_API_KEY', '<key>', 'User')

# 對當前 session 也補吃一次（registry 寫了但 process 不會 reload）
$env:ZAI_API_KEY = [Environment]::GetEnvironmentVariable('ZAI_API_KEY', 'User')
```

之後新開的 PS 7 session 直接打 `claude-zai` 即可。

### WSL bash（一次性 WSLENV 設定）

```powershell
# Windows-side：把 ZAI_API_KEY 加進 WSLENV propagation list（保留現有 vars）
$cur = [Environment]::GetEnvironmentVariable('WSLENV', 'User')
if (-not ($cur -split ':' | Where-Object { $_ -match '^ZAI_API_KEY(/|$)' })) {
    $new = if ($cur) { "${cur}:ZAI_API_KEY/u" } else { 'ZAI_API_KEY/u' }
    [Environment]::SetEnvironmentVariable('WSLENV', $new, 'User')
}

# WSL 已跑著的 distro 不會 reload env，需重啟才生效
wsl --terminate Ubuntu   # 收掉現有 session（zellij 等請先存好）
```

之後新開的 WSL bash 直接打 `claude-zai` 即可。`$ZAI_API_KEY` 由 Windows kernel 自動 propagate，不需在 WSL 內再 export。

## 使用

### Windows PS 7

```powershell
claude-zai                              # 用預設 model
claude-zai -OpusModel 'GLM-4.6'         # 單次覆寫主推理 model
claude-zai mcp list                      # CC 子命令照樣帶
claude-zai --resume                      # CC flag 照樣帶
```

### WSL bash

```bash
claude-zai                              # 預設 model
ZAI_OPUS_MODEL=GLM-4.6 claude-zai       # 單次覆寫（bash 行內 env 慣用法）
claude-zai mcp list                      # CC 子命令照樣帶
claude-zai --resume                      # CC flag 照樣帶
```

> Bash 用**行內 env var** 覆寫（`ZAI_OPUS_MODEL`、`ZAI_SONNET_MODEL`、`ZAI_HAIKU_MODEL`、`ZAI_TIMEOUT_MS`）而非命名參數，避免跟 `claude` 自己的 args 競爭 positional。PS 用 named params 是 PowerShell 慣例。兩邊功能對等。

### 預設 model tier 對應

| CC tier | z.ai model | 用途 |
|---------|-----------|------|
| Opus | `GLM-5.1` | 主對話、複雜推理 |
| Sonnet | `GLM-5` | `/model sonnet` 切換時 |
| Haiku | `GLM-5-Turbo` | auto-compaction、conversation title、subagent default |

三個 tier 指向**三個不同 model**，讓 CC 內 `/model opus|sonnet|haiku` 切換能真的換到不同 model
（z.ai 官方推薦的 `GLM-4.7` 在 opus/sonnet 兩 tier 都用同一個，等於切了等於沒切）。

### 可覆寫的參數

| 參數 | 預設 |
|------|------|
| `-OpusModel` | `GLM-5.1` |
| `-SonnetModel` | `GLM-5` |
| `-HaikuModel` | `GLM-5-Turbo` |
| `-TimeoutMs` | `3000000`（50 分鐘，z.ai 官方建議） |

### Wrapper 內部會設的 env var（離開後還原）

| Env var | 值 |
|---------|-----|
| `ANTHROPIC_BASE_URL` | `https://api.z.ai/api/anthropic` |
| `ANTHROPIC_AUTH_TOKEN` | `$env:ZAI_API_KEY` |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | `-OpusModel` |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | `-SonnetModel` |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | `-HaikuModel` |
| `API_TIMEOUT_MS` | `-TimeoutMs` |

PowerShell 函式內動 `$env:` 會洩漏到 process scope（不像普通變數那樣 function-scoped），所以 wrapper 用 `try/finally` 把這 6 個 env var snapshot 後還原，確保**離開 `claude-zai` 就完全乾淨**。

## 注意事項

- **z.ai 沒有對應 Opus 4.7 水準的 model**。GLM family 整體在 hard reasoning、long-horizon planning、subtle refactoring 落後 Anthropic frontier。賣點是 token 成本低 + 中文場景優勢 + Coding Plan 訂閱經濟。
- **CC UI 顯示的 model 字串仍是 `claude-opus-4-7` 等**——那是 CC 內部 tier-to-name 映射，跟後端實際 GLM model 無關。要驗證真的用了 GLM，看 z.ai dashboard 的 usage。
- **Prompt caching 命中率會顯著掉**——Anthropic 5 分鐘 cache TTL 那套對 z.ai 不適用，原本 cache-friendly 的 system prompt 不見得能在 z.ai 一樣省 token。
- **Statusline `cost` / `rate_limits` 欄位可能顯示異常**——CC 從 API response `usage` shape 解，z.ai 若不完全對齊會空值或誤算；`five_hour` / `seven_day` 是 Claude.ai 訂閱專屬，必定不會出現。
- **Tool use / thinking blocks 相容性是常見踩雷點**——若出現「卡住但 process 還活著」或「tool call 跑一半斷掉」，多半是 z.ai 端 adapter 對 Anthropic streaming SSE event 順序或 thinking shape 不完全相容；拿同 prompt 跑純 `claude` 對照可確認。
- **`/model` 在 z.ai 場景的意義**：只在你 wrapper 啟動時把 opus/sonnet/haiku 指向不同 z.ai model 時才有切換效果。三個 tier 都指同一個 model 時，`/model` 切等於沒切。
- **API key 安全性**：HKCU\Environment 是**明文**（任何能讀使用者 registry 的程式都看得到）。測試階段可接受，長期建議 Phase 2 改 gopass。

## 移除（回到動手前）

### Windows PS 7

```powershell
Remove-Item "$env:USERPROFILE\Documents\PowerShell\profile.d\25-claude-zai.ps1"
[Environment]::SetEnvironmentVariable('ZAI_API_KEY', $null, 'User')
Remove-Item C:\Users\user\claude-zai.ps1 -ErrorAction SilentlyContinue
```

### WSL bash + WSLENV

```bash
# WSL 內砍掉 claude-zai function 段（保留 zellij 區塊）
sed -i '/^# ── claude-zai:/,$d' ~/.bashrc.local
```

```powershell
# Windows-side：從 WSLENV 拆掉 ZAI_API_KEY/u
$cur = [Environment]::GetEnvironmentVariable('WSLENV', 'User')
$new = ($cur -split ':' | Where-Object { $_ -notmatch '^ZAI_API_KEY(/|$)' }) -join ':'
[Environment]::SetEnvironmentVariable('WSLENV', $new, 'User')
```

清完，chezmoi source 完全沒被動過。

## Phase 2 規劃（chezmoi + gopass）

- Wrapper 進 `Documents/exact__shared-profile.d/`（與 `which`、`Edit-WTSettings` 等共用函式同住）
- 函式內把 `$env:ZAI_API_KEY` 改成 `gopass show -o z.ai/claude-code-token`
- 移除 registry 明文 key、改走 gopass 加密 + 跨機 sync

不走 `~/.claude/settings.json` 的 `env` block（z.ai 官方文件建議路徑）的理由：
1. 那是**全域**設定，每次跑 `claude` 都套用，沒辦法快速切回 Anthropic
2. `settings.json` 已由 `modify_settings.json.sh.tmpl` 用 jq patch 管理，多寫 `env` block 會跟 chezmoi 流程打架
3. Wrapper try/finally 保證「離開 z.ai = 真的離開」，settings.json env 沒這個保護

## Phase 3a 設計筆記（WSL bash）

### 為什麼 bash 不需要 try/finally

PS 函式內動 `$env:` 會洩漏到 process scope（必須 snapshot+restore）；bash 的 `VAR=val cmd` 行內 env 語法**天然只影響子進程**，函式回來後 parent shell 完全乾淨。所以 bash wrapper 兩行就解決：

```bash
ANTHROPIC_BASE_URL='https://api.z.ai/api/anthropic' \
... \
claude "$@"
```

### 為什麼放在 `~/.bashrc.local` 而非 chezmoi source

`bashrc/linux` 第 29 行明確標註：「各機器的本機客製內容放 `~/.bashrc.local`，這個檔不被 chezmoi 管」。完美符合「scratch + auto-load」需求：

- 不在 chezmoi source → 不需 commit、易刪
- 由 dotfiles 部署的 `.bashrc` 主動 source → 跟 Windows `profile.d/*.ps1` 對稱、auto-load

### 為什麼用 `WSLENV` 而非 WSL 內各自 export

`WSLENV=ZAI_API_KEY/u` 讓 Windows User env var 在 WSL 啟動時自動 inject。**單一 source of truth**——之後 rotate key 只動 Windows 那份，WSL 重啟自動同步。`/u` flag 限制單向（Windows→WSL），WSL 內若有同名 var 不會反向污染 Windows process。

### 啟動 ordering 與 zellij 共存

`.bashrc.local` 內順序：

```
1. zellij auto-attach 區塊（含 exec）
2. claude-zai function 定義
```

- **本機 WSL bash**（無 `$SSH_CONNECTION`）：zellij 區塊跳過 → 繼續往下 → claude-zai 載入
- **SSH 外層 bash**：被 `exec zellij` 取代，外層 shell 消失（claude-zai 沒載到也無所謂）
- **zellij pane subshells**：重新 source `.bashrc` → `.bashrc.local`，`$ZELLIJ` 已設 → zellij 區塊跳過 → claude-zai 載入

## Phase 3b 規劃（剩餘平台）

### macOS（純 zsh）

zsh 跟 bash 同樣支援 `VAR=val cmd` 行內 env 語法，wrapper 函式可直接搬用。但 macOS 沒有 `WSLENV` 概念——`ZAI_API_KEY` 要嘛從 macOS-side 自己設、要嘛走 Phase 2 的 gopass。

### 純 Linux 機器（非 WSL）

同 macOS——`ZAI_API_KEY` 從 Linux-side 自己設或走 gopass。函式定義位置可繼承 `.bashrc.local` pattern。

### 跨平台統一進 chezmoi（合併 Phase 2）

進 `.chezmoitemplates/shell-common/base` 後，**Linux/WSL/macOS/Git Bash 全部 fan-out**。要做的時候建議跟 token 改 gopass 一起做，一次反轉到位、不留中間狀態。

## 相關文件

- [Claude Code 設定](claude-code.md)
- [PowerShell Profile](powershell.md)
- [Bash 設定](bash.md)
