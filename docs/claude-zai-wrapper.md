# claude-zai Wrapper

讓 Claude Code 切換到 [z.ai](https://docs.z.ai/) 的 Anthropic-compatible endpoint，
跑 GLM 系列 model 而不是 Anthropic 原生。設計成 wrapper 函式，**不污染** `claude` 主指令——
平常工作維持 Anthropic，需要試 GLM 時打 `claude-zai`。

> 本文件記載設定、使用方式與本案專屬的取捨。跨 change 反覆適用的判斷依據在 [`context/`](../context/index.md)。

## 目前狀態

| 項目 | 狀態 |
|------|------|
| Phase 1（Windows PS 7 wrapper） | ✅ 已進 chezmoi |
| Phase 2（`pass` / `gopass` 存 token，跨平台 fan-out） | ⏹ 已被 Phase 4 取代（2026-09-29） |
| Phase 3a（WSL bash wrapper） | ✅ 已進 chezmoi |
| Phase 3b（macOS zsh / 純 Linux）| ⚠️ wrapper 已進 chezmoi；macOS 沒有 Bitwarden reader，只吃 `$ZAI_API_KEY` |
| Phase 4（token 改走 Bitwarden `bw serve`） | ✅ 已進 chezmoi（2026-09-29） |
| Windows gopass 解密 | ⏹ 不再適用：wrapper 不讀 `gopass` |

Wrapper code 全部進 chezmoi source。Token source 是 Bitwarden item `z.ai/claude-code-token`，經 `bw serve` 讀取。
Linux/WSL 用 `~/.local/bin/bw-get`，Windows 用 `Get-BwSecret`。macOS 只用 `$ZAI_API_KEY`。

## 部署位置（chezmoi-managed）

| 平台 | 路徑 | 內容 |
|------|------|------|
| 跨平台 bash/zsh | `.chezmoitemplates/shell-common/base` → `~/.shell_common` | `claude-zai()` 函式 |
| Windows PS 5/7 | `Documents/exact__shared-profile.d/25-claude-zai.ps1` → `~/Documents/_shared-profile.d/25-claude-zai.ps1` | `claude-zai` 函式（兩個 profile loader 都 source） |
| Linux / WSL | `dot_local/bin/executable_bw-get` → `~/.local/bin/bw-get` | 從 `bw serve` 讀一個 item 的欄位 |
| Windows PS 5/7 | `Documents/exact__shared-profile.d/24-bw-get.ps1` | `Get-BwSecret` 函式（在 25 之前載入） |

Token 來源：

| 平台 | Reader | Item |
|------|--------|------|
| Linux / WSL | `~/.local/bin/bw-get z.ai/claude-code-token` | `z.ai/claude-code-token` 的 `login.password` |
| Windows | `Get-BwSecret -Name z.ai/claude-code-token` | 同上（同一個 `bw serve`、同一個 item） |
| macOS | 無 | 只用 `$ZAI_API_KEY` |

`bw serve` 在 Windows 上跑，聽 `localhost:8087`，同時服務 Windows 與 WSL。
登入時由 `bw-serve-unlock` 排程工作啟動並解鎖。
設定方式見 [corp-ssh-setup.md](corp-ssh-setup.md) 與 [corp-ssh-setup-windows.md](corp-ssh-setup-windows.md)，本文不重複。

## 一次性設定

### 1. 把 token 存進 Bitwarden

在任一 Bitwarden client（web vault、桌面 app、瀏覽器擴充、`bw`）建立 item：

| Item 名稱 | 欄位 | 值 |
|-----------|------|----|
| `z.ai/claude-code-token` | `login.password` | z.ai API key |

名稱要完全一致，大小寫也算。
用跟 corp-ssh 同一個 Bitwarden 帳號。這個帳號只放公司的 item；z.ai 帳號是公司帳號，所以放這裡。
一個 item 同時服務 Windows 與 WSL，不必同步到其他機器。

`bw serve` 要在跑且已解鎖。從 WSL 驗證：

```bash
curl.exe -s http://localhost:8087/status    # 要看到 "status":"unlocked"
```

從 `pass` 搬過來的遷移已在 2026-09-29 完成。沒有任何東西會刪掉舊的 `pass` entry `z.ai/claude-code-token`。

### 2. 換 token

在任一 Bitwarden client 改 item `z.ai/claude-code-token` 的 `login.password`。
Reader 只在 `bw serve` 的 vault 副本超過 10 分鐘才 sync，所以新 token 最多約 10 分鐘後生效。
跑一次 corp ssh 登入會立刻 sync。

### 3. （選用）registry env var fallback

平常**不需要** registry 明文 key。
wrapper 保留 `$env:ZAI_API_KEY` fallback，只在 `bw serve` 沒跑、已上鎖、或 item 不存在時用得到。
macOS 沒有 Bitwarden reader，只能靠這個 fallback。
要設可以設，平常不必：

```powershell
# 選用：僅供 bw serve 不可用時 fallback
[Environment]::SetEnvironmentVariable('ZAI_API_KEY', '<key>', 'User')
```

`WSLENV=ZAI_API_KEY/u` **不再需要**（WSL 經 `bw-get` 讀同一個 item，不靠 propagation），可以一併拆掉：

```powershell
$cur = [Environment]::GetEnvironmentVariable('WSLENV', 'User')
$new = ($cur -split ':' | Where-Object { $_ -notmatch '^ZAI_API_KEY(/|$)' }) -join ':'
[Environment]::SetEnvironmentVariable('WSLENV', $new, 'User')
wsl --terminate Ubuntu   # 收掉現有 WSL session 讓新 env 生效
```

## 使用

### Bash / Zsh (WSL / Linux / macOS / Git Bash)

```bash
claude-zai                              # 預設 model
ZAI_OPUS_MODEL=GLM-4.6 claude-zai       # 單次覆寫（bash 行內 env 慣用法）
claude-zai mcp list                      # CC 子命令照樣帶
claude-zai --resume                      # CC flag 照樣帶
```

可覆寫 env var：`ZAI_OPUS_MODEL`、`ZAI_SONNET_MODEL`、`ZAI_HAIKU_MODEL`、`ZAI_TIMEOUT_MS`。

### PowerShell 7（與 5）

```powershell
claude-zai                              # 預設 model
claude-zai -OpusModel 'GLM-4.6'         # 單次覆寫
claude-zai mcp list                      # CC 子命令照樣帶
claude-zai --resume                      # CC flag 照樣帶
```

可覆寫 named param：`-OpusModel`、`-SonnetModel`、`-HaikuModel`、`-TimeoutMs`。

### 預設 model tier 對應

| CC tier | z.ai model | 用途 |
|---------|-----------|------|
| Opus | `GLM-5.2` | 主對話、複雜推理 |
| Sonnet | `GLM-5.1` | `/model sonnet` 切換時 |
| Haiku | `GLM-5` | auto-compaction、conversation title、subagent default |

三個 tier 指向**三個不同 model**，讓 CC 內 `/model opus|sonnet|haiku` 切換能真的換到不同 model
（z.ai 官方推薦的 `GLM-4.7` 在 opus/sonnet 兩 tier 都用同一個，等於切了等於沒切）。

### Wrapper 內部會設的 env var

| Env var | 值 |
|---------|-----|
| `ANTHROPIC_BASE_URL` | `https://api.z.ai/api/anthropic` |
| `ANTHROPIC_AUTH_TOKEN` | Bitwarden item 取出的 token（或 fallback 到 `$ZAI_API_KEY`） |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | `-OpusModel` / `$ZAI_OPUS_MODEL` |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | `-SonnetModel` / `$ZAI_SONNET_MODEL` |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | `-HaikuModel` / `$ZAI_HAIKU_MODEL` |
| `API_TIMEOUT_MS` | `-TimeoutMs` / `$ZAI_TIMEOUT_MS`（預設 50 分鐘，z.ai 官方建議） |

PowerShell 函式內動 `$env:` 會洩漏到 process scope（不像普通變數那樣 function-scoped），所以 PS wrapper 用 `try/finally` 把這 6 個 env var snapshot 後還原。Bash/zsh 的 `VAR=val cmd` 行內 env 語法天然只影響子進程，不需 snapshot。

## Token resolution 優先順序（兩平台共通）

1. **Bitwarden item**：`~/.local/bin/bw-get z.ai/claude-code-token`（Linux/WSL）/ `Get-BwSecret -Name z.ai/claude-code-token`（Windows）
2. **Env var fallback**：`$ZAI_API_KEY`
3. 兩者皆無 → wrapper 報錯不執行，訊息是 `no token (Bitwarden item z.ai/claude-code-token unreadable and $ZAI_API_KEY unset)`

`bw-get` 的 exit code：0 成功；1 沒有這個 item 或欄位是空的；2 `bw serve` 連不到或已上鎖。
`Get-BwSecret` 任何失敗都回 `$null`。任何失敗 wrapper 都改用 `$ZAI_API_KEY`。

正常情況跑 1。`bw serve` 不可用時、macOS、CI 容器跑 2。

## 注意事項

- **z.ai 沒有對應 Opus 4.7 水準的 model**。GLM family 整體在 hard reasoning、long-horizon planning、subtle refactoring 落後 Anthropic frontier。賣點是 token 成本低 + 中文場景優勢 + Coding Plan 訂閱經濟。
- **CC UI 顯示的 model 字串仍是 `claude-opus-4-7` 等**——那是 CC 內部 tier-to-name 映射，跟後端實際 GLM model 無關。要驗證真的用了 GLM，看 z.ai dashboard 的 usage。
- **Prompt caching 命中率會顯著掉**——Anthropic 5 分鐘 cache TTL 那套對 z.ai 不適用，原本 cache-friendly 的 system prompt 不見得能在 z.ai 一樣省 token。
- **Statusline `cost` / `rate_limits` 欄位可能顯示異常**——CC 從 API response `usage` shape 解，z.ai 若不完全對齊會空值或誤算；`five_hour` / `seven_day` 是 Claude.ai 訂閱專屬，必定不會出現。
- **Tool use / thinking blocks 相容性是常見踩雷點**——若出現「卡住但 process 還活著」或「tool call 跑一半斷掉」，多半是 z.ai 端 adapter 對 Anthropic streaming SSE event 順序或 thinking shape 不完全相容；拿同 prompt 跑純 `claude` 對照可確認。
- **`/model` 在 z.ai 場景的意義**：只在你 wrapper 啟動時把 opus/sonnet/haiku 指向不同 z.ai model 時才有切換效果。三個 tier 都指同一個 model 時，`/model` 切等於沒切。
- **Windows gopass 解密（歷史，已被 Phase 4 取代）**：wrapper 自 2026-09-29 起不讀 `gopass`，以下只留作紀錄。scoop gpg 2.5.20 的 `gpgconf.ctl` 把 GnuPG 鎖進 portable 模式（homedir 變空、GNUPGHOME 被忽略），`gopass show` 解不開 vault。Wave 8 把 gpg 移出 scoop（vanilla gnupg.org 裝到 `~/.local/opt/gnupg`，無 gpgconf.ctl）後 Windows 自動走 vault 模式，wrapper 完全不用改。完整失敗鏈見 memory `reference_corp_ssh_windows_askpass_chain.md`。

## 移除（回到動手前）

1. 在任一 Bitwarden client 刪掉 item `z.ai/claude-code-token`。
2. （選用）舊的 `pass` entry 還在，沒有東西會刪它。要清就在 WSL 跑：

```bash
pass rm z.ai/claude-code-token
```

3. Windows registry 那把 fallback key：

```powershell
[Environment]::SetEnvironmentVariable('ZAI_API_KEY', $null, 'User')
```

Wrapper 本身在 chezmoi source，整個 z.ai 嘗試結束後若要連 wrapper 也拿掉，刪掉這兩個檔案再 `chezmoi apply`：

- `.chezmoitemplates/shell-common/base` 內 `claude-zai()` 那段
- `Documents/exact__shared-profile.d/25-claude-zai.ps1`

## 設計筆記

### 為什麼 token 走 vault 而不是 env var

明文環境變數與加密 vault 的取捨屬一般依據，見 [`context/`](../context/index.md) 的原則清單。
落到本案的代價：`bw serve` 要在跑且已解鎖；macOS 沒有 reader，只能用 env var。

`pass` / `gopass` 時期（Phase 2，已被取代）的代價不同：gpg-agent 沒 warm 時要打一次 passphrase，跨機器要先把 entry 的 encrypted blob 複製過去。
改走 Bitwarden 後，一個 item 服務 Windows 與 WSL，這兩項代價都消失了。

### 為什麼 wrapper code 進 chezmoi 而不是 scratch

四個 wrapper 變體（PS / WSL bash / macOS zsh / 純 Linux bash）若各自手寫，必養出 inconsistency。進 `shell-common/base` 後 Linux/WSL/macOS/Git Bash 一份 code 全部 fan-out；PS 一份 code 同時給 PS 5 與 PS 7（透過 `_shared-profile.d` loader）。

### 為什麼 PS 用 named param、bash 用 env var 覆寫

PowerShell 函式天生支援 named param（`[CmdletBinding()] param(...)`），符合 PS 慣例。Bash function 沒對應語法，行內 env (`VAR=val cmd`) 是 bash/zsh 慣用法且天然 process-scoped，沒洩漏問題。兩邊功能對等。

### 為什麼不直接寫進 `~/.claude/settings.json` 的 `env` block

z.ai 官方文件建議走 settings.json env，但：

1. 那是**全域**設定，每次跑 `claude` 都套用，沒辦法快速切回 Anthropic。
2. `settings.json` 已由 `modify_settings.json.sh.tmpl` 用 jq patch 管理，多寫 `env` block 會跟 chezmoi 流程打架。
3. Wrapper try/finally 保證「離開 z.ai = 真的離開」，settings.json env 沒這個保護。

### 為什麼 `WSLENV` propagation 拆掉

Phase 3a 用 `WSLENV=ZAI_API_KEY/u` 讓 Windows env var 自動 inject 到 WSL，當時 WSL 沒裝 pass。Phase 2 後 WSL 走 vault，那條 propagation 失去意義——WSL 直接讀本地 vault，比 propagation 還省。Phase 4 後 WSL 經 `bw-get` 讀 Windows 上的 `bw serve`，propagation 仍然不需要。Windows 端的 registry env var 仍可當選用 fallback。

## 相關文件

- [Claude Code 設定](claude-code.md)
- [PowerShell Profile](powershell.md)
- [Bash 設定](bash.md)
