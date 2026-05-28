# claude-zai Wrapper

讓 Claude Code 切換到 [z.ai](https://docs.z.ai/) 的 Anthropic-compatible endpoint，
跑 GLM 系列 model 而不是 Anthropic 原生。設計成 wrapper 函式，**不污染** `claude` 主指令——
平常工作維持 Anthropic，需要試 GLM 時打 `claude-zai`。

## 目前狀態

| 項目 | 狀態 |
|------|------|
| Phase 1（Windows PS 7 本機部署） | ✅ 已啟用 |
| Phase 2（chezmoi 管理 + gopass 存 key） | ⏳ 規劃中 |
| Phase 3（跨平台到 WSL / Linux / macOS） | ⏳ 規劃中 |

Phase 1 採「**本機部署、不進 chezmoi source**」做法，方便快速試味道；確認長期要用後再走 Phase 2。

## 部署位置（Phase 1）

| 路徑 | 用途 |
|------|------|
| `~/Documents/PowerShell/profile.d/25-claude-zai.ps1` | wrapper 函式定義（PS 7 自動載入） |
| `~/claude-zai.ps1` | 原始 scratch 檔（可砍） |
| `HKCU\Environment\ZAI_API_KEY` | z.ai API key（Windows user-level env var） |

> 都在使用者目錄底下，不在 `D:\ws\github\dotfiles\` 內，所以 `chezmoi diff` 會顯示 `profile.d/25-claude-zai.ps1` 為 extra file，但不會被 apply 砍掉。

## 一次性設定

```powershell
# 設 z.ai API key（落到 registry HKCU\Environment）
[Environment]::SetEnvironmentVariable('ZAI_API_KEY', '<key>', 'User')

# 對當前 session 也補吃一次（registry 寫了但 process 不會 reload）
$env:ZAI_API_KEY = [Environment]::GetEnvironmentVariable('ZAI_API_KEY', 'User')
```

之後新開的 PS 7 session 直接打 `claude-zai` 即可，函式由 profile loader 自動 source。

## 使用

```powershell
claude-zai                              # 用預設 model
claude-zai -OpusModel 'GLM-4.6'         # 單次覆寫主推理 model
claude-zai mcp list                      # CC 子命令照樣帶
claude-zai --resume                      # CC flag 照樣帶
```

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

```powershell
Remove-Item "$env:USERPROFILE\Documents\PowerShell\profile.d\25-claude-zai.ps1"
[Environment]::SetEnvironmentVariable('ZAI_API_KEY', $null, 'User')
Remove-Item C:\Users\user\claude-zai.ps1
```

三行清完，chezmoi source 完全沒被動過。

## Phase 2 規劃（chezmoi + gopass）

- Wrapper 進 `Documents/exact__shared-profile.d/`（與 `which`、`Edit-WTSettings` 等共用函式同住）
- 函式內把 `$env:ZAI_API_KEY` 改成 `gopass show -o z.ai/claude-code-token`
- 移除 registry 明文 key、改走 gopass 加密 + 跨機 sync

不走 `~/.claude/settings.json` 的 `env` block（z.ai 官方文件建議路徑）的理由：
1. 那是**全域**設定，每次跑 `claude` 都套用，沒辦法快速切回 Anthropic
2. `settings.json` 已由 `modify_settings.json.sh.tmpl` 用 jq patch 管理，多寫 `env` block 會跟 chezmoi 流程打架
3. Wrapper try/finally 保證「離開 z.ai = 真的離開」，settings.json env 沒這個保護

## Phase 3 規劃（跨平台 WSL / Linux / macOS）

WSL 同步需要兩件事各自處理：

### 1. API key 跨 Windows ↔ WSL

選項：

| 做法 | 優點 | 缺點 |
|------|------|------|
| `WSLENV=ZAI_API_KEY/u` 自動 propagate | 單一 source of truth（Windows User env var） | 仍是明文 |
| WSL bashrc 內 `export ZAI_API_KEY=...` | 各自獨立 | 兩處同步維護 |
| **Phase 2 走 gopass + WSL 共用 store** | 加密 + 統一 | 需 gopass 跨平台設定（已部署） |

### 2. Bash 版 wrapper 函式

Bash/zsh 的 `VAR=val cmd` 行內 env 語法天然只影響子進程，不需要 try/finally 機制：

```bash
claude-zai() {
    [ -z "$ZAI_API_KEY" ] && { echo "ZAI_API_KEY not set" >&2; return 1; }
    ANTHROPIC_BASE_URL='https://api.z.ai/api/anthropic' \
    ANTHROPIC_AUTH_TOKEN="$ZAI_API_KEY" \
    ANTHROPIC_DEFAULT_OPUS_MODEL="${ZAI_OPUS_MODEL:-GLM-5.1}" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="${ZAI_SONNET_MODEL:-GLM-5}" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="${ZAI_HAIKU_MODEL:-GLM-5-Turbo}" \
    API_TIMEOUT_MS="${ZAI_TIMEOUT_MS:-3000000}" \
    claude "$@"
}
```

進 chezmoi 時應放 `.chezmoitemplates/shell-common/base`（跨平台 fragment），讓 Linux/WSL/macOS 都吃到。

### 前置：WSL 內是否有 `claude` 指令

WSL 跑 bash wrapper 的前提是 **WSL 內裝了 Claude Code 本體**。兩種狀況：

- **WSL 內已裝**：bash wrapper 直接呼 WSL 內的 `claude`，跟 Windows 完全獨立
- **WSL 內沒裝**：要不就在 WSL 內 `npm i -g @anthropic-ai/claude-code` 裝一份；要不就接受「WSL 內不能用 `claude-zai`」

從 WSL 呼叫 Windows 的 `claude.exe`（透過 `/mnt/c/...` 跨界）技術上可行但**強烈不建議**：路徑翻譯、TTY、檔案 watch、subagent worker 都會踩雷，[Claude Code 在 Windows 的進程模型](../claude/statusline/) 已經夠複雜，跨 WSL/Windows 邊界更不穩。

## 相關文件

- [Claude Code 設定](claude-code.md)
- [PowerShell Profile](powershell.md)
- [Bash 設定](bash.md)
