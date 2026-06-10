# claude-zai Wrapper

讓 Claude Code 切換到 [z.ai](https://docs.z.ai/) 的 Anthropic-compatible endpoint，
跑 GLM 系列 model 而不是 Anthropic 原生。設計成 wrapper 函式，**不污染** `claude` 主指令——
平常工作維持 Anthropic，需要試 GLM 時打 `claude-zai`。

## 目前狀態

| 項目 | 狀態 |
|------|------|
| Phase 1（Windows PS 7 wrapper） | ✅ 已進 chezmoi |
| Phase 2（vault 存 token，跨平台 fan-out） | ✅ 已進 chezmoi |
| Phase 3a（WSL bash wrapper） | ✅ 已進 chezmoi |
| Phase 3b（macOS zsh / 純 Linux）| ✅ 同 Phase 2，等實際機器部署 |
| Windows gopass 解密 | ✅ 已修（gpg 移出 scoop，Wave 8 / 2026-06-10）；vault 正常解密，registry 降為選用 fallback |

Wrapper code 全部進 chezmoi source，Token source 走 vault（WSL `pass` / macOS+Linux 同；Windows 走 `gopass`，gpg 移出 scoop 後正常解密）。

## 部署位置（chezmoi-managed）

| 平台 | 路徑 | 內容 |
|------|------|------|
| 跨平台 bash/zsh | `.chezmoitemplates/shell-common/base` → `~/.shell_common` | `claude-zai()` 函式 |
| Windows PS 5/7 | `Documents/exact__shared-profile.d/25-claude-zai.ps1` → `~/Documents/_shared-profile.d/25-claude-zai.ps1` | `claude-zai` 函式（兩個 profile loader 都 source） |

Token vault：

| 平台 | CLI | Entry path |
|------|-----|------------|
| WSL / Linux / macOS | `pass` | `z.ai/claude-code-token` |
| Windows | `gopass` | 同上（共享 `%USERPROFILE%\.password-store\`） |

## 一次性設定

### 1. 把 token 存進 vault

任一台已裝 `pass` + 已 init password store 的機器（最常見是 WSL）：

```bash
# 直接 paste key，按 Enter，再 Ctrl+D 結束
pass insert -e z.ai/claude-code-token

# 或從現有 env var 灌進去
printf '%s' "$ZAI_API_KEY" | pass insert -e -f z.ai/claude-code-token
```

Insert 後跑一次 `pass show z.ai/claude-code-token`，第一次會彈 pinentry 要 passphrase（之後 gpg-agent cache 起來）。

### 2. （選用）同步到其他機器

`~/.password-store/z.ai/claude-code-token.gpg` 是 GPG-encrypted blob，可以直接 `scp` / `rsync` 或經由 Windows ↔ WSL 共用路徑複製過去。recipient 同（同一把 GPG key），對端解得開。

```bash
# WSL → Windows store
cp ~/.password-store/z.ai/claude-code-token.gpg /mnt/c/Users/$USER/.password-store/z.ai/
```

### 3. （選用）registry env var fallback

gpg 移出 scoop（Wave 8）後 Windows `gopass show` 正常解密，**不再需要** registry 明文 key。
wrapper 仍保留 `$env:ZAI_API_KEY` fallback，只在 vault 不可用（沒裝 gpg / CI 容器）時用得到——
要設可以設，平常不必：

```powershell
# 選用：僅供無 gpg 環境 fallback
[Environment]::SetEnvironmentVariable('ZAI_API_KEY', '<key>', 'User')
```

`WSLENV=ZAI_API_KEY/u` 在 Phase 2 之後**不再需要**（WSL 走 `pass`，不靠 propagation），可以一併拆掉：

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
| Opus | `GLM-5.1` | 主對話、複雜推理 |
| Sonnet | `GLM-5` | `/model sonnet` 切換時 |
| Haiku | `GLM-5-Turbo` | auto-compaction、conversation title、subagent default |

三個 tier 指向**三個不同 model**，讓 CC 內 `/model opus|sonnet|haiku` 切換能真的換到不同 model
（z.ai 官方推薦的 `GLM-4.7` 在 opus/sonnet 兩 tier 都用同一個，等於切了等於沒切）。

### Wrapper 內部會設的 env var

| Env var | 值 |
|---------|-----|
| `ANTHROPIC_BASE_URL` | `https://api.z.ai/api/anthropic` |
| `ANTHROPIC_AUTH_TOKEN` | vault 取出的 token（或 fallback 到 `$ZAI_API_KEY`） |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | `-OpusModel` / `$ZAI_OPUS_MODEL` |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | `-SonnetModel` / `$ZAI_SONNET_MODEL` |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | `-HaikuModel` / `$ZAI_HAIKU_MODEL` |
| `API_TIMEOUT_MS` | `-TimeoutMs` / `$ZAI_TIMEOUT_MS`（預設 50 分鐘，z.ai 官方建議） |

PowerShell 函式內動 `$env:` 會洩漏到 process scope（不像普通變數那樣 function-scoped），所以 PS wrapper 用 `try/finally` 把這 6 個 env var snapshot 後還原。Bash/zsh 的 `VAR=val cmd` 行內 env 語法天然只影響子進程，不需 snapshot。

## Token resolution 優先順序（兩平台共通）

1. **Vault**：`pass show z.ai/claude-code-token` (Unix) / `gopass show -o z.ai/claude-code-token` (Windows)
2. **Env var fallback**：`$ZAI_API_KEY`
3. 兩者皆無 → wrapper 報錯不執行

正常情況跑 1（含 Windows，gpg 移出 scoop 後 vault 正常）；CI / 沒裝 gpg 的容器跑 2。

## 注意事項

- **z.ai 沒有對應 Opus 4.7 水準的 model**。GLM family 整體在 hard reasoning、long-horizon planning、subtle refactoring 落後 Anthropic frontier。賣點是 token 成本低 + 中文場景優勢 + Coding Plan 訂閱經濟。
- **CC UI 顯示的 model 字串仍是 `claude-opus-4-7` 等**——那是 CC 內部 tier-to-name 映射，跟後端實際 GLM model 無關。要驗證真的用了 GLM，看 z.ai dashboard 的 usage。
- **Prompt caching 命中率會顯著掉**——Anthropic 5 分鐘 cache TTL 那套對 z.ai 不適用，原本 cache-friendly 的 system prompt 不見得能在 z.ai 一樣省 token。
- **Statusline `cost` / `rate_limits` 欄位可能顯示異常**——CC 從 API response `usage` shape 解，z.ai 若不完全對齊會空值或誤算；`five_hour` / `seven_day` 是 Claude.ai 訂閱專屬，必定不會出現。
- **Tool use / thinking blocks 相容性是常見踩雷點**——若出現「卡住但 process 還活著」或「tool call 跑一半斷掉」，多半是 z.ai 端 adapter 對 Anthropic streaming SSE event 順序或 thinking shape 不完全相容；拿同 prompt 跑純 `claude` 對照可確認。
- **`/model` 在 z.ai 場景的意義**：只在你 wrapper 啟動時把 opus/sonnet/haiku 指向不同 z.ai model 時才有切換效果。三個 tier 都指同一個 model 時，`/model` 切等於沒切。
- **Windows gopass 解密（已修，2026-06-10）**：scoop gpg 2.5.20 的 `gpgconf.ctl` 把 GnuPG 鎖進 portable 模式（homedir 變空、GNUPGHOME 被忽略），`gopass show` 解不開 vault。Wave 8 把 gpg 移出 scoop（vanilla gnupg.org 裝到 `~/.local/opt/gnupg`，無 gpgconf.ctl）後 Windows 自動走 vault 模式，wrapper 完全不用改。完整失敗鏈見 memory `reference_corp_ssh_windows_askpass_chain.md`。

## 移除（回到動手前）

```bash
# 1. 從 vault 砍掉 entry
pass rm z.ai/claude-code-token

# 2. （所有共用該 vault 的 Windows store 也要刪）
rm /mnt/c/Users/$USER/.password-store/z.ai/claude-code-token.gpg 2>/dev/null
rmdir /mnt/c/Users/$USER/.password-store/z.ai 2>/dev/null
```

```powershell
# 3. Windows registry 那把 fallback key
[Environment]::SetEnvironmentVariable('ZAI_API_KEY', $null, 'User')
```

Wrapper 本身在 chezmoi source，整個 z.ai 嘗試結束後若要連 wrapper 也拿掉，刪掉這兩個檔案再 `chezmoi apply`：

- `.chezmoitemplates/shell-common/base` 內 `claude-zai()` 那段
- `Documents/exact__shared-profile.d/25-claude-zai.ps1`

## 設計筆記

### 為什麼 token 走 vault 而不是 env var

`HKCU\Environment` 跟 `~/.bashrc` 內的 export 都是**明文**，任何能讀使用者環境的程式都看得到。Vault 用 GPG 加密、gpg-agent 短期 unlock，passphrase-protected。重大下行：gpg-agent 沒 warm 時要打 passphrase（一次性），跨機器要先把 entry encrypt blob 複製過去。

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

Phase 3a 用 `WSLENV=ZAI_API_KEY/u` 讓 Windows env var 自動 inject 到 WSL，當時 WSL 沒裝 pass。Phase 2 後 WSL 走 vault，那條 propagation 失去意義——WSL 直接讀本地 vault，比 propagation 還省。Windows 端的 registry env var 仍保留當 fallback（直到 Windows gopass bug 修好）。

## 相關文件

- [Claude Code 設定](claude-code.md)
- [PowerShell Profile](powershell.md)
- [Bash 設定](bash.md)
