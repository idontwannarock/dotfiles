# WezTerm Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 將 Windows 主機從 Windows Terminal 遷移到 WezTerm，盡可能 1:1 複製現有 WT 外觀與行為，並新增「Split pane 切換 profile + 繼承 cwd」三組 keybinding（Ctrl+Alt+P/B/U）。

**Architecture:** Lua 設定 (`~/.config/wezterm/wezterm.lua`) 走 chezmoi template 部署 (`dot_config/wezterm/wezterm.lua.tmpl`)。3 個 profile（PowerShell 7、Git Bash、WSL Ubuntu）的 cwd 繼承靠 OSC 7 escape sequence——三邊 shell rcfile 各自加 PROMPT_COMMAND/PreCommand 廣播。WezTerm 收到 OSC 7 後，新 pane 的 SpawnCommand 不指定 cwd 就會自動繼承當前 pane 的最後一次 OSC 7 值。Windows Terminal chezmoi 設定保留不動（fallback）。

**Tech Stack:** WezTerm (Rust)、Lua 5.4、chezmoi、Scoop、PowerShell 7、Git Bash、WSL Ubuntu bash

---

## Scope

**範圍內：**
- Windows 主機 wezterm 設定（`~/.config/wezterm/wezterm.lua`）
- 三個 shell 的 OSC 7 emission：PowerShell（PS5/PS7 共用）、Git Bash、WSL Ubuntu bash
- chezmoi source 同步、安裝腳本、文件、memory

**範圍外：**
- macOS / Linux 桌面跑 wezterm（使用者沒這個 use case；Linux 操作都是 TUI 透過 WSL）
- 但 **WSL Ubuntu 內 `~/.bashrc` 的 OSC 7 emission 還是要做**——WezTerm 的 WSL domain 會 spawn WSL bash 進來顯示在 wezterm pane，pane 內的 bash 還是要 emit OSC 7 給 wezterm 接收

---

## 工作流程鐵律（來自使用者 CLAUDE.md）

```
1. 先在當前電腦測試 → 直接改 ~/.config/wezterm/wezterm.lua、~/.bashrc 等
2. 確認生效後再同步 → 把已驗證的內容搬到 chezmoi source
3. 跨平台考量 → wezterm.lua 用 chezmoi template 條件分支（其實本案 Windows-only）
4. 更新文件 → docs/wezterm-setup.md + memory
```

**所有 Phase A 任務都在當前電腦的 home 目錄直接改，先用後同步；Phase B 才動 chezmoi source。**

---

## 既有 WT 設定盤點（來源：`%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`）

⚠️ **下表「信心」中等的項目，Phase A Task 10 結束時要做一次「視覺/行為對照」**——肉眼檢查跟 WT 是否相同；如有差異，記錄在 plan 末尾的「Phase A 測試報告」並決定要不要調整。

### Global behavior
| WT 設定 | 值 | WezTerm 等價 | 信心 |
|---|---|---|---|
| `copyFormatting` | `"none"` | WezTerm 預設行為一致（純 plain text） | 高 |
| `copyOnSelect` | `false` | WezTerm 預設一致（選取不自動複製） | 高 |
| `defaultInputScope` | `"alphanumericHalfWidth"` | 無等價（Windows IME 設定，非 terminal 控制） | 高 |
| `launchMode` | `"maximized"` | `gui-startup` callback + `window:maximize()` | 中 |
| `tabWidthMode` | `"titleLength"` | `tab_max_width = 32`（接近行為，非 1:1） | 中 |
| `windowingBehavior` | `"useExisting"` | Windows 預設行為一致 | 中 |
| `defaultProfile` | PowerShell GUID | `default_prog = { 'pwsh.exe', '-NoLogo' }` | 高 |

### Appearance (profiles.defaults)
| WT 設定 | 值 | WezTerm 等價 | 信心 |
|---|---|---|---|
| `cursorShape` | `"filledBox"` | `default_cursor_style = 'SteadyBlock'` | 高 |
| `font.face` | `"CaskaydiaCove Nerd Font Mono"` | `font = wezterm.font('CaskaydiaCove Nerd Font Mono')` | 高 |
| `font.size` | `13` | `font_size = 13.0` | 高 |
| `intenseTextStyle` | `"all"` | `bold_brightens_ansi_colors = 'BrightAndBold'` | 中 |
| 預設 colorScheme | `Campbell` (WT 預設) | `color_scheme = 'Campbell'` | 中 |

### Profiles (visible)
| Name | GUID | Commandline | startingDirectory |
|---|---|---|---|
| PowerShell | `{574e775e-...}` | (PS Core source — `pwsh.exe`) | (default) |
| Git Bash | `{59809b0c-...}` | `C:\Users\user\scoop\apps\git\current\bin\bash.exe` | `%USERPROFILE%` |
| Ubuntu | `{2b970378-...}` | (WSL source — `wsl.exe -d Ubuntu`) | (default) |

### 既有 keybindings 取捨

| WT keys | WT action | 是否複製到 WezTerm |
|---|---|---|
| ~~`alt+shift+d`~~ | ~~splitPane auto duplicate~~ | ❌ **拿掉** |
| `alt+shift+plus` | splitPane right duplicate | ✅ 保留 |
| `alt+shift+minus` | splitPane down duplicate | ✅ 保留 |
| `alt+shift+方向鍵` | resize pane | ✅ 保留 |
| ~~`ctrl+shift+f`~~ | ~~find~~ | ❌ **拿掉** |
| `ctrl+v` | paste | ✅ 保留 |
| `ctrl+c` | copy | ✅ 保留（要實測 fallthrough） |

### 新增需求
| Keys | Action |
|---|---|
| `Ctrl+Alt+P` | Split pane Auto → PowerShell 7（繼承 cwd） |
| `Ctrl+Alt+B` | Split pane Auto → Git Bash（繼承 cwd） |
| `Ctrl+Alt+U` | Split pane Auto → WSL Ubuntu（繼承 cwd 透過 WSL domain） |

---

## 檔案結構

### Phase A 在 home 直接編輯（暫存區）
- `C:\Users\user\.config\wezterm\wezterm.lua` — wezterm 主設定
- `C:\Users\user\Documents\PowerShell\Profile.d\91-wezterm-osc7.ps1` — PS OSC 7 emission
- `C:\Users\user\.bashrc`（Git Bash 用，會被 chezmoi 覆蓋）— 暫時手動加 OSC 7 測試
- WSL Ubuntu `~/.bashrc` — 暫時手動加 OSC 7 測試

### Phase B 同步進 chezmoi source（最終位置）
- `D:\ws\github\dotfiles\dot_config\wezterm\wezterm.lua.tmpl` — wezterm 設定
- `D:\ws\github\dotfiles\Documents\exact__shared-profile.d\91-wezterm-osc7.ps1` — PS OSC 7（共用 PS5/PS7）
- `D:\ws\github\dotfiles\.chezmoitemplates\bashrc\windows` — 加 OSC 7（給 Git Bash）
- `D:\ws\github\dotfiles\.chezmoitemplates\bashrc\linux` — 加 OSC 7（給 WSL bash）
- `D:\ws\github\dotfiles\run_once_install-cli-tools.ps1.tmpl` — 加 wezterm scoop install
- `D:\ws\github\dotfiles\.chezmoiignore.tmpl` — 非 Windows 排除 `.config/wezterm`
- `D:\ws\github\dotfiles\docs\wezterm-setup.md` — 使用文件（**包含所有跨機器/別人接手該知道的細節**）
- `C:\Users\user\.claude\projects\D--ws-github-dotfiles\memory\` — 新增 wezterm 相關 memory（**只放本機個人決策脈絡**，不 commit）

### 不動的檔案
- `run_onchange_configure-windows-terminal.ps1.tmpl` — 保留 WT 設定當 fallback

---

# Phase A: 本機驗證（暫存實作 → 確認 OK 才進 chezmoi）

## Task 1: 安裝 WezTerm

**Files:**
- Create: `C:\Users\user\.config\wezterm\wezterm.lua`（建立空檔讓 wezterm 第一次啟動有東西載）

- [ ] **Step 1: Scoop install wezterm**

```powershell
scoop bucket add extras
scoop install wezterm
```

- [ ] **Step 2: 觀察 scoop install 的 post-install messages**

注意 scoop 安裝完印出的 hint 訊息——很多 scoop extras package 會提示「如何加 Explorer 右鍵 context menu」，要把訊息存下來給 Task 18 用。

```powershell
scoop info wezterm  # 會印出 notes 區塊
```

- [ ] **Step 3: 驗證安裝**

```powershell
wezterm --version
```

Expected: `wezterm 2024xxxx-xxxxxx-xxxxxxxx ...`（版本字串）

- [ ] **Step 4: 建立空 wezterm.lua（避免第一次啟動跳預設提示）**

```powershell
New-Item -ItemType Directory -Force -Path "$HOME\.config\wezterm" | Out-Null
```

Write `C:\Users\user\.config\wezterm\wezterm.lua`:
```lua
local wezterm = require 'wezterm'
local config = wezterm.config_builder()
return config
```

- [ ] **Step 5: 第一次啟動確認**

從開始選單啟動 WezTerm，確認：
- 視窗開得起來
- 預設跑 cmd.exe（之後會改）
- 沒有 config error 對話框

- [ ] **Step 6: 不 commit**（這個檔案是暫存區，Phase B 才搬進 chezmoi）

## Task 2: 複製 WT appearance（font / cursor / colors）

**Files:**
- Modify: `C:\Users\user\.config\wezterm\wezterm.lua`

- [ ] **Step 1: 加入外觀設定**

```lua
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ── Appearance ──
config.font = wezterm.font('CaskaydiaCove Nerd Font Mono')
config.font_size = 13.0
config.bold_brightens_ansi_colors = 'BrightAndBold'  -- 對應 WT 的 intenseTextStyle="all"
config.default_cursor_style = 'SteadyBlock'           -- 對應 WT 的 cursorShape="filledBox"

-- ── Color scheme ──
-- WT 預設用 Campbell scheme; WezTerm 內建有同名 scheme
config.color_scheme = 'Campbell'

return config
```

- [ ] **Step 2: 重新啟動 WezTerm 驗證**

關掉 WezTerm 重開（或 `Ctrl+Shift+R` reload config）。確認：
- 字型是 CaskaydiaCove Nerd Font（icon 顯示正常）
- 字體大小視覺上跟 WT 一致
- 游標是實心方塊
- 顏色是 WT 那種 Campbell 配色

## Task 3: 複製 WT 行為（窗口、複製、launch maximized）

**Files:**
- Modify: `C:\Users\user\.config\wezterm\wezterm.lua`

- [ ] **Step 1: 加入行為設定**

在 `return config` 之前插入：
```lua
-- ── Window behavior ──
config.initial_cols = 120
config.initial_rows = 30
config.window_decorations = 'TITLE | RESIZE'  -- WT 風格的 title bar
config.tab_bar_at_bottom = false
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 32

-- ── Window padding（接近 WT 的觀感）──
config.window_padding = {
  left = 4,
  right = 4,
  top = 4,
  bottom = 4,
}

-- ── Copy/Paste 行為（對應 copyOnSelect=false）──
-- WezTerm 預設選取後不自動複製，行為已一致；無需額外設定

-- ── Launch maximized ──
wezterm.on('gui-startup', function(cmd)
  local _, _, window = wezterm.mux.spawn_window(cmd or {})
  window:gui_window():maximize()
end)
```

- [ ] **Step 2: Reload config 驗證**

按 `Ctrl+Shift+R`（WezTerm 預設 reload key）。新開 window 應該：
- 啟動時 maximized
- Tab bar 在頂部
- 窗口 padding 自然

## Task 4: 設定 PowerShell 7 為 default、註冊 3 個 launch profile

**Files:**
- Modify: `C:\Users\user\.config\wezterm\wezterm.lua`

- [ ] **Step 1: 加入 default_prog + launch_menu + WSL domain prefix-match**

在前面已有的 config 後面（`return config` 前）加：
```lua
-- ── Default shell ──
config.default_prog = { 'pwsh.exe', '-NoLogo' }

-- ── WSL domains（從 wsl -l -v 自動偵測；找出第一個 Ubuntu* distro）──
config.wsl_domains = wezterm.default_wsl_domains()
local ubuntu_domain_name = nil
for _, dom in ipairs(config.wsl_domains) do
  if dom.name:match('^WSL:Ubuntu') then
    ubuntu_domain_name = dom.name
    break
  end
end

-- ── Launch menu（對應 WT 的 newTabMenu）──
local git_bash = os.getenv('USERPROFILE') .. '\\scoop\\apps\\git\\current\\bin\\bash.exe'

config.launch_menu = {
  {
    label = 'PowerShell',
    args = { 'pwsh.exe', '-NoLogo' },
  },
  {
    label = 'Git Bash',
    args = { git_bash, '-l' },
  },
  {
    label = 'Ubuntu (WSL)',
    args = { 'wsl.exe', '-d', 'Ubuntu', '--cd', '~' },
  },
}
```

- [ ] **Step 2: Reload + 驗證 launch menu**

按 `Ctrl+Shift+Space`（WezTerm 的 launcher menu 預設 key），確認三個 profile 都列出來且能正常啟動。

- [ ] **Step 3: 驗證新 tab 預設開 PS7**

`Ctrl+Shift+T` 開新 tab，應該是 PowerShell 7（顯示 `PS C:\>` 或 starship prompt）。

- [ ] **Step 4: 驗證 ubuntu_domain_name 被找到**

```lua
-- 暫時加進 config 印出檢查（驗證後拿掉）
wezterm.log_info('Ubuntu domain detected: ' .. tostring(ubuntu_domain_name))
```

按 `Ctrl+Shift+L` 開 debug overlay，看 log 印什麼。預期：`WSL:Ubuntu` 或 `WSL:Ubuntu-XX.XX`。如果是 `nil` 表示 prefix-match 失敗，要回頭檢查 `wsl -l -v` 輸出。

## Task 5: 複製 WT keybindings（resize + duplicate plus/minus + copy/paste）

**Files:**
- Modify: `C:\Users\user\.config\wezterm\wezterm.lua`

⚠️ 不複製 `Alt+Shift+D`（auto duplicate）和 `Ctrl+Shift+F`（find）——使用者要求拿掉。

- [ ] **Step 1: 加入 keybinding 表**

在 `return config` 之前加：
```lua
local act = wezterm.action

config.keys = {
  -- ── Split pane (duplicate current profile，明確方向) ──
  -- 對應 WT alt+shift+plus (right split duplicate)
  { key = '+', mods = 'ALT|SHIFT',
    action = act.SplitPane { direction = 'Right', command = { domain = 'CurrentPaneDomain' } } },
  -- 對應 WT alt+shift+minus (down split duplicate)
  { key = '-', mods = 'ALT|SHIFT',
    action = act.SplitPane { direction = 'Down', command = { domain = 'CurrentPaneDomain' } } },

  -- ── Resize pane ──
  { key = 'LeftArrow',  mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Left', 5 } },
  { key = 'RightArrow', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Right', 5 } },
  { key = 'UpArrow',    mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Up', 5 } },
  { key = 'DownArrow',  mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Down', 5 } },

  -- ── Copy / Paste（對應 WT ctrl+c/v；WezTerm 預設是 ctrl+shift+c/v，這裡覆寫）──
  -- 注意：ctrl+c 在 shell 是中斷訊號，WezTerm 預設智慧處理（有選取時複製，無選取時送中斷）
  { key = 'c', mods = 'CTRL', action = act.CopyTo 'Clipboard' },
  { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
}
```

- [ ] **Step 2: Reload + 驗證每個 keybinding**

逐一測試：
- `Alt+Shift+Plus` 在當前 pane 右邊 split 同 profile
- `Alt+Shift+Minus` 在當前 pane 下方 split 同 profile
- `Alt+Shift+方向鍵` resize pane → 寬度/高度應該變化
- 選取文字後 `Ctrl+C` → 進剪貼簿；空白處按 `Ctrl+C` → 送中斷訊號到 shell
- `Ctrl+V` → 貼上剪貼簿內容

⚠️ **若 Ctrl+C 行為不對**：WezTerm 對 `CopyTo Clipboard` 的「無選取時 fallthrough」需要 `act.CopyTo 'ClipboardAndPrimarySelection'` 或更精細的 conditional。若有問題，改用 `Ctrl+Shift+C`/`Ctrl+Shift+V`（WezTerm 預設）並記在 known issues。

## Task 6: 加入 3 個 cross-profile split keybinding（Auto direction）

**Files:**
- Modify: `C:\Users\user\.config\wezterm\wezterm.lua`

- [ ] **Step 1: 在 config.keys 表後追加（用 Auto 讓 wezterm 自選方向）**

```lua
-- ── Cross-profile split (Auto direction，繼承 cwd 透過 OSC 7) ──
table.insert(config.keys, { key = 'p', mods = 'CTRL|ALT',
  action = act.SplitPane {
    direction = 'Auto',
    command = { args = { 'pwsh.exe', '-NoLogo' } },
    -- 不指定 cwd → WezTerm 自動繼承當前 pane 最後的 OSC 7
  } })

table.insert(config.keys, { key = 'b', mods = 'CTRL|ALT',
  action = act.SplitPane {
    direction = 'Auto',
    command = { args = { git_bash, '-l' } },
  } })

-- WSL: 如果 prefix-match 失敗則 fallback 不掛鍵（避免錯誤行為）
if ubuntu_domain_name then
  table.insert(config.keys, { key = 'u', mods = 'CTRL|ALT',
    action = act.SplitPane {
      direction = 'Auto',
      command = { domain = { DomainName = ubuntu_domain_name } },
    } })
end
```

- [ ] **Step 2: Reload，驗證 keybinding 觸發但 cwd 還沒繼承**

從 PS pane 按 `Ctrl+Alt+B` → 應該開出 Git Bash pane，但目前 cwd 會是 home（OSC 7 還沒設定）。確認 keybinding 至少能觸發目標 profile，這 task 算過。

## Task 7: PowerShell 加 OSC 7 emission（wrap function 與 OSC 9;9 共存）

**Files:**
- Create: `C:\Users\user\Documents\PowerShell\Profile.d\91-wezterm-osc7.ps1`
- Verify: `C:\Users\user\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`（檢查 profile.d loader 已存在）

- [ ] **Step 1: 確認 PS profile loader pattern**

Read `C:\Users\user\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` 確認它有 source `Profile.d\*.ps1` 的機制。如果沒有的話，這 task 改成直接 append 到 `Microsoft.PowerShell_profile.ps1`（並在 Phase B Task 12 同步進 chezmoi 時也對應調整）。

- [ ] **Step 2: 寫 OSC 7 emission script（wrap 既有 PreCommand 不覆蓋）**

Write `C:\Users\user\Documents\PowerShell\Profile.d\91-wezterm-osc7.ps1`:
```powershell
# WezTerm OSC 7 - 報告當前工作目錄（讓 WezTerm split pane 繼承 cwd）
# 偵測 WezTerm 環境後才掛 hook，避免汙染其他 terminal
# 與既有 90-prompt.ps1 的 OSC 9;9 (給 WT 用) 並存——用 wrap function 模式串接

if ($env:TERM_PROGRAM -eq 'WezTerm' -or $env:WEZTERM_PANE) {
    function global:Invoke-WezTermOsc7 {
        $loc = $executionContext.SessionState.Path.CurrentLocation
        if ($loc.Provider.Name -ne 'FileSystem') { return }
        $path = $loc.ProviderPath -replace '\\', '/'
        # 簡易 URL encode（空格、中文等的 percent encoding）
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($path)
        $encoded = ($bytes | ForEach-Object {
            if (($_ -ge 0x30 -and $_ -le 0x39) -or `
                ($_ -ge 0x41 -and $_ -le 0x5A) -or `
                ($_ -ge 0x61 -and $_ -le 0x7A) -or `
                $_ -eq 0x2D -or $_ -eq 0x2E -or $_ -eq 0x5F -or $_ -eq 0x7E -or $_ -eq 0x2F) {
                [char]$_
            } else {
                "%{0:X2}" -f $_
            }
        }) -join ''
        $hostname = [System.Net.Dns]::GetHostName()
        $esc = [char]27
        Write-Host -NoNewline ("$esc]7;file://$hostname$encoded$esc\")
    }

    # 與既有 Invoke-Starship-PreCommand 整合：保留原 hook（OSC 9;9）並串接 OSC 7
    if (Get-Command Invoke-Starship-PreCommand -ErrorAction SilentlyContinue) {
        $existing = (Get-Item Function:Invoke-Starship-PreCommand).ScriptBlock
        function global:Invoke-Starship-PreCommand {
            & $existing
            Invoke-WezTermOsc7
        }
    } else {
        function global:Invoke-Starship-PreCommand {
            Invoke-WezTermOsc7
        }
    }
}
```

- [ ] **Step 3: 驗證 OSC 7 emission**

開新 PS pane（透過 WezTerm，不是 WT）。`cd D:\ws\github\dotfiles`。按 `Alt+Shift+Plus` → 新開 pane 應該也在 `D:\ws\github\dotfiles`（不是 home）。

⚠️ **若沒繼承**：用 `Get-Variable PROMPT` 或寫 debug 行驗證 `Invoke-WezTermOsc7` 真的被呼叫。可能是 Starship init 順序問題——確認 `91-wezterm-osc7.ps1` 在 `90-prompt.ps1` 之後 source。

⚠️ **驗證 OSC 9;9 沒被破壞**：到 WT 開新 pane 也測一下 cwd 繼承（WT 用的 OSC 9;9，wrap 不能讓它失效）。

## Task 8: Git Bash 加 OSC 7 emission（含 idempotent guard）

**Files:**
- Modify: `C:\Users\user\.bashrc`（暫存區，Phase B 才搬進 chezmoi template）

- [ ] **Step 1: 加 OSC 7 PROMPT_COMMAND（含重複 source 防護）**

在 `C:\Users\user\.bashrc` 末尾加（注意：這個檔案是 chezmoi 部署的，編輯只是暫時測試，會被 `chezmoi apply` 覆蓋；先測試行為，Phase B 把這段同步進 source）：
```bash
# ── WezTerm OSC 7 CWD 整合 ──
# 讓 WezTerm split pane 繼承當前目錄
if [ "$TERM_PROGRAM" = "WezTerm" ] || [ -n "$WEZTERM_PANE" ]; then
    _wezterm_osc7() {
        local cwd_url
        # Git Bash 的 $PWD 已是 unix-style 路徑（/c/Users/...）
        # 需轉回 Windows path 給 WezTerm 識別
        local win_path
        win_path="$(cygpath -w "$PWD" 2>/dev/null | tr '\\' '/')"
        # cygpath 不存在時 fallback 用 unix path（WezTerm 通常還是能解析）
        [ -z "$win_path" ] && win_path="$PWD"
        # URL encode（簡易版：留下 /、字母、數字、-_.~）
        cwd_url="$(printf '%s' "$win_path" | awk '
            BEGIN { for (i=0; i<256; i++) hex[sprintf("%c", i)] = sprintf("%%%02X", i) }
            { for (i=1; i<=length($0); i++) {
                c = substr($0, i, 1)
                if (c ~ /[A-Za-z0-9._~\/-]/) printf "%s", c
                else printf "%s", hex[c]
            } }')"
        printf "\033]7;file://%s%s\033\\" "$(hostname)" "$cwd_url"
    }
    # Idempotent guard：只在 PROMPT_COMMAND 還沒有 _wezterm_osc7 時才掛
    case "$PROMPT_COMMAND" in
        *_wezterm_osc7*) ;;  # already installed, skip
        *) PROMPT_COMMAND=${PROMPT_COMMAND:+"$PROMPT_COMMAND; "}_wezterm_osc7 ;;
    esac
fi
```

- [ ] **Step 2: source 立即生效**

```bash
source ~/.bashrc
# 多 source 幾次驗證 idempotent guard
source ~/.bashrc
source ~/.bashrc
echo "$PROMPT_COMMAND"
# 應該只看到一個 _wezterm_osc7
```

- [ ] **Step 3: 驗證 cwd 繼承**

從 WezTerm 開 Git Bash pane，`cd /d/ws/github/dotfiles`。從 PS pane 按 `Ctrl+Alt+B` → 新 pane 應該在同一個目錄。

## Task 9: WSL Ubuntu 加 OSC 7 emission（含 idempotent guard）

**Files:**
- Modify: WSL Ubuntu 的 `~/.bashrc`（暫存區）

- [ ] **Step 1: 進 WSL Ubuntu**

```powershell
wsl -d Ubuntu
```

- [ ] **Step 2: 加 OSC 7（WSL 版，路徑要轉成 Windows 看得懂的格式）**

在 WSL 的 `~/.bashrc` 末尾加：
```bash
# ── WezTerm OSC 7 CWD 整合 (WSL) ──
# 讓 WezTerm split pane 繼承當前目錄
if [ "$TERM_PROGRAM" = "WezTerm" ] || [ -n "$WEZTERM_PANE" ]; then
    _wezterm_osc7() {
        local path="$PWD"
        # URL encode
        local encoded
        encoded="$(printf '%s' "$path" | awk '
            BEGIN { for (i=0; i<256; i++) hex[sprintf("%c", i)] = sprintf("%%%02X", i) }
            { for (i=1; i<=length($0); i++) {
                c = substr($0, i, 1)
                if (c ~ /[A-Za-z0-9._~\/-]/) printf "%s", c
                else printf "%s", hex[c]
            } }')"
        # 用 distro 的 hostname；wezterm 看到 hostname 不是當前主機就走 wsl domain
        printf "\033]7;file://%s%s\033\\" "$(hostname)" "$encoded"
    }
    # Idempotent guard
    case "$PROMPT_COMMAND" in
        *_wezterm_osc7*) ;;
        *) PROMPT_COMMAND=${PROMPT_COMMAND:+"$PROMPT_COMMAND; "}_wezterm_osc7 ;;
    esac
fi
```

- [ ] **Step 3: source 並驗證**

```bash
source ~/.bashrc
source ~/.bashrc  # 多 source 確認 idempotent
echo "$PROMPT_COMMAND"
cd /home/$USER
```

從 WezTerm 開 WSL Ubuntu pane，cd 到某個目錄，然後 `Alt+Shift+Plus` duplicate → 應該在同目錄。

⚠️ **跨 domain 切換的限制**：從 WSL 用 `Ctrl+Alt+P` 切到 PowerShell 可能無法繼承 cwd（WSL `/home/user` 在 Windows 沒有對應路徑）。這是預期行為——WezTerm 會 fallback 到 PowerShell 的 default cwd。

## Task 10: Phase A 完整驗證 + WT 對應表勘誤

- [ ] **Step 1: 跨 profile cwd 繼承測試矩陣**

開三個 pane：PS、Git Bash、Ubuntu。每個 pane cd 到不同目錄。然後測：

| 從 | 按 | 預期新 pane |
|---|---|---|
| PS @ `D:\ws\github\dotfiles` | `Ctrl+Alt+B` | Git Bash @ `/d/ws/github/dotfiles` |
| PS @ `D:\ws\github\dotfiles` | `Ctrl+Alt+U` | Ubuntu @ `/mnt/d/ws/github/dotfiles` |
| Git Bash @ `/d/ws/github` | `Ctrl+Alt+P` | PS @ `D:\ws\github` |
| Git Bash @ `/c/Users/user` | `Ctrl+Alt+U` | Ubuntu @ `/mnt/c/Users/user` |
| Ubuntu @ `/mnt/d/ws` | `Ctrl+Alt+P` | PS @ `D:\ws` |
| Ubuntu @ `/home/user` | `Ctrl+Alt+P` | PS @ home（fallback，預期） |
| Ubuntu @ `/home/user` | `Ctrl+Alt+B` | Git Bash @ home（fallback，預期） |

- [ ] **Step 2: WT 既有功能對照測試**

| 行為 | WT | WezTerm | 通過？ |
|---|---|---|---|
| 啟動 maximized | ✓ | ? | |
| 字型對 | CaskaydiaCove | ? | |
| 字體大小 | 13 | ? | |
| 游標方塊 | ✓ | ? | |
| `intenseTextStyle="all"` 對應 bold 顯示 | ✓ | ? | |
| Campbell 配色一致 | ✓ | ? | |
| Tab 寬度視覺 | titleLength | tab_max_width=32 | |
| Alt+Shift+Plus 同 cwd 同 shell | ✓ | ? | |
| Alt+Shift+Minus 同 cwd 同 shell | ✓ | ? | |
| Alt+Shift+方向鍵 resize | ✓ | ? | |
| Ctrl+C 複製/中斷 fallthrough | ✓ | ? | |
| Ctrl+V 貼上 | ✓ | ? | |
| 選取不自動複製 | ✓ | ? | |

- [ ] **Step 3: 中信心項目勘誤決策**

如果上表中：
- `intenseTextStyle="all"` 對應不上 → 試試 `bold_brightens_ansi_colors = 'BrightOnly'` 或 `'No'`
- `Campbell` 顏色不一致 → 列出差異，必要時換 `'Campbell (Gogh)'` 或 export WT 的 scheme 移植過來
- `tab_max_width=32` 視覺差太多 → 調整數字或試 `tab_bar_at_bottom = true`

把測試報告填進 plan 末尾的「Phase A 測試報告」表格。

- [ ] **Step 4: 測試矩陣 + WT 對照都通過才進 Phase B**

任一項失敗或有 known issue 先停下來討論，不進 Phase B。

---

# Phase B: 同步進 chezmoi source

每個 task 結尾都要 `git push origin main`（你 OK 過：commit 完就 push，不影響原本操作或環境）。

## Task 11: 把 wezterm.lua 搬進 chezmoi template

**Files:**
- Create: `D:\ws\github\dotfiles\dot_config\wezterm\wezterm.lua.tmpl`
- Modify: `D:\ws\github\dotfiles\.chezmoiignore.tmpl`

- [ ] **Step 1: 把 Phase A 驗證過的 ~/.config/wezterm/wezterm.lua 內容複製到 source**

Write `D:\ws\github\dotfiles\dot_config\wezterm\wezterm.lua.tmpl`（內容從 Phase A 的最終版複製，並把 hardcoded `os.getenv('USERPROFILE')` 改成 chezmoi template `{{ .chezmoi.homeDir }}`）：

```lua
{{- /* WezTerm 設定 — Windows 主機；其他平台暫時排除 */ -}}
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ── Appearance ──
config.font = wezterm.font('CaskaydiaCove Nerd Font Mono')
config.font_size = 13.0
config.bold_brightens_ansi_colors = 'BrightAndBold'
config.default_cursor_style = 'SteadyBlock'
config.color_scheme = 'Campbell'

-- ── Window behavior ──
config.initial_cols = 120
config.initial_rows = 30
config.window_decorations = 'TITLE | RESIZE'
config.tab_bar_at_bottom = false
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 32
config.window_padding = { left = 4, right = 4, top = 4, bottom = 4 }

-- ── Launch maximized ──
wezterm.on('gui-startup', function(cmd)
  local _, _, window = wezterm.mux.spawn_window(cmd or {})
  window:gui_window():maximize()
end)

-- ── Default shell ──
config.default_prog = { 'pwsh.exe', '-NoLogo' }

-- ── WSL domains（從 wsl -l -v 自動偵測；找出第一個 Ubuntu* distro）──
config.wsl_domains = wezterm.default_wsl_domains()
local ubuntu_domain_name = nil
for _, dom in ipairs(config.wsl_domains) do
  if dom.name:match('^WSL:Ubuntu') then
    ubuntu_domain_name = dom.name
    break
  end
end

-- ── Launch menu ──
local git_bash = '{{ .chezmoi.homeDir }}\\scoop\\apps\\git\\current\\bin\\bash.exe'

config.launch_menu = {
  { label = 'PowerShell', args = { 'pwsh.exe', '-NoLogo' } },
  { label = 'Git Bash',   args = { git_bash, '-l' } },
  { label = 'Ubuntu (WSL)', args = { 'wsl.exe', '-d', 'Ubuntu', '--cd', '~' } },
}

-- ── Keybindings ──
local act = wezterm.action

config.keys = {
  -- Split pane (duplicate, 明確方向)
  { key = '+', mods = 'ALT|SHIFT', action = act.SplitPane { direction = 'Right', command = { domain = 'CurrentPaneDomain' } } },
  { key = '-', mods = 'ALT|SHIFT', action = act.SplitPane { direction = 'Down',  command = { domain = 'CurrentPaneDomain' } } },

  -- Resize pane
  { key = 'LeftArrow',  mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Left', 5 } },
  { key = 'RightArrow', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Right', 5 } },
  { key = 'UpArrow',    mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Up', 5 } },
  { key = 'DownArrow',  mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Down', 5 } },

  -- Copy / Paste（覆寫 WezTerm 預設的 ctrl+shift+c/v）
  { key = 'c', mods = 'CTRL', action = act.CopyTo 'Clipboard' },
  { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },

  -- Cross-profile split (Auto direction，繼承 cwd 透過 OSC 7)
  { key = 'p', mods = 'CTRL|ALT', action = act.SplitPane { direction = 'Auto', command = { args = { 'pwsh.exe', '-NoLogo' } } } },
  { key = 'b', mods = 'CTRL|ALT', action = act.SplitPane { direction = 'Auto', command = { args = { git_bash, '-l' } } } },
}

-- WSL keybinding（如果 prefix-match 成功才掛）
if ubuntu_domain_name then
  table.insert(config.keys, { key = 'u', mods = 'CTRL|ALT',
    action = act.SplitPane { direction = 'Auto', command = { domain = { DomainName = ubuntu_domain_name } } } })
end

return config
```

- [ ] **Step 2: 加非 Windows 排除規則**

Edit `D:\ws\github\dotfiles\.chezmoiignore.tmpl`，在「Windows 專屬」區塊加：
```
{{- if ne .chezmoi.os "windows" }}
.config/wezterm
{{- end }}
```

- [ ] **Step 3: chezmoi diff 確認**

```powershell
chezmoi diff --include=files | Select-String -Context 0,5 wezterm
```

Expected: 看到 `.config/wezterm/wezterm.lua` 出現在 diff，且內容與 Phase A 驗證過的版本一致（差別只在 git_bash 路徑用 `{{ .chezmoi.homeDir }}` 渲染後等於 `C:\Users\user`）。

- [ ] **Step 4: chezmoi apply 並重啟 WezTerm 驗證**

```powershell
chezmoi apply
```

關掉所有 WezTerm window 重開，確認所有 Task 10 的測試矩陣項目仍然通過。

- [ ] **Step 5: Commit + Push**

```bash
git add dot_config/wezterm/wezterm.lua.tmpl .chezmoiignore.tmpl
git commit -m "feat(wezterm): add wezterm config with cross-profile split keybindings"
git push origin main
```

## Task 12: 把 PowerShell OSC 7 搬進 chezmoi

**Files:**
- Create: `D:\ws\github\dotfiles\Documents\exact__shared-profile.d\91-wezterm-osc7.ps1`

- [ ] **Step 1: 從 home 複製內容到 source**

```powershell
Copy-Item C:\Users\user\Documents\PowerShell\Profile.d\91-wezterm-osc7.ps1 `
          D:\ws\github\dotfiles\Documents\exact__shared-profile.d\91-wezterm-osc7.ps1
```

如果 Phase A Task 7 是直接 append 到 `Microsoft.PowerShell_profile.ps1` 而不是 Profile.d 模式，這裡要先重構成 Profile.d 一致的模式。

- [ ] **Step 2: chezmoi diff 確認**

```powershell
chezmoi diff Documents/PowerShell/Profile.d/91-wezterm-osc7.ps1
```

- [ ] **Step 3: chezmoi apply + 驗證 PS 還能繼承 cwd**

```powershell
chezmoi apply
```

開新 PS pane，重複 Task 7 Step 3 的驗證。

- [ ] **Step 4: Commit + Push**

```bash
git add Documents/exact__shared-profile.d/91-wezterm-osc7.ps1
git commit -m "feat(powershell): emit OSC 7 for WezTerm cwd inheritance"
git push origin main
```

## Task 13: 把 Git Bash OSC 7 搬進 chezmoi bashrc/windows fragment

**Files:**
- Modify: `D:\ws\github\dotfiles\.chezmoitemplates\bashrc\windows`

- [ ] **Step 1: 在 windows fragment 末尾加 OSC 7 區塊（含 idempotent guard）**

Edit `D:\ws\github\dotfiles\.chezmoitemplates\bashrc\windows`，在 starship init 之後加：
```bash
# ── WezTerm OSC 7 CWD 整合 ──
# 讓 WezTerm split pane 繼承當前目錄
if [ "$TERM_PROGRAM" = "WezTerm" ] || [ -n "$WEZTERM_PANE" ]; then
    _wezterm_osc7() {
        local win_path
        win_path="$(cygpath -w "$PWD" 2>/dev/null | tr '\\' '/')"
        [ -z "$win_path" ] && win_path="$PWD"
        local cwd_url
        cwd_url="$(printf '%s' "$win_path" | awk '
            BEGIN { for (i=0; i<256; i++) hex[sprintf("%c", i)] = sprintf("%%%02X", i) }
            { for (i=1; i<=length($0); i++) {
                c = substr($0, i, 1)
                if (c ~ /[A-Za-z0-9._~\/-]/) printf "%s", c
                else printf "%s", hex[c]
            } }')"
        printf "\033]7;file://%s%s\033\\" "$(hostname)" "$cwd_url"
    }
    case "$PROMPT_COMMAND" in
        *_wezterm_osc7*) ;;
        *) PROMPT_COMMAND=${PROMPT_COMMAND:+"$PROMPT_COMMAND; "}_wezterm_osc7 ;;
    esac
fi
```

- [ ] **Step 2: chezmoi apply + 重啟 Git Bash pane 驗證**

```powershell
chezmoi apply
```

關掉所有 Git Bash pane 重開，驗證 cwd 繼承仍正常。

- [ ] **Step 3: Commit + Push**

```bash
git add .chezmoitemplates/bashrc/windows
git commit -m "feat(bashrc): emit OSC 7 in Git Bash for WezTerm cwd inheritance"
git push origin main
```

⚠️ **Task 14 依賴這個 push 完成**——下一個 task 會在 WSL 內 `chezmoi update` 拉這個 commit。

## Task 14: 把 WSL bash OSC 7 搬進 chezmoi bashrc/linux fragment

**Files:**
- Modify: `D:\ws\github\dotfiles\.chezmoitemplates\bashrc\linux`

⚠️ **依賴 Task 13 的 push 已完成**

- [ ] **Step 1: 在 linux fragment 內加 OSC 7 區塊（含 idempotent guard）**

Edit `D:\ws\github\dotfiles\.chezmoitemplates\bashrc\linux`，在現有的 WT OSC 9;9 區塊之後（或同層）加：
```bash
# ── WezTerm OSC 7 CWD 整合 (WSL) ──
if [ "$TERM_PROGRAM" = "WezTerm" ] || [ -n "$WEZTERM_PANE" ]; then
    _wezterm_osc7() {
        local path="$PWD"
        local encoded
        encoded="$(printf '%s' "$path" | awk '
            BEGIN { for (i=0; i<256; i++) hex[sprintf("%c", i)] = sprintf("%%%02X", i) }
            { for (i=1; i<=length($0); i++) {
                c = substr($0, i, 1)
                if (c ~ /[A-Za-z0-9._~\/-]/) printf "%s", c
                else printf "%s", hex[c]
            } }')"
        printf "\033]7;file://%s%s\033\\" "$(hostname)" "$encoded"
    }
    case "$PROMPT_COMMAND" in
        *_wezterm_osc7*) ;;
        *) PROMPT_COMMAND=${PROMPT_COMMAND:+"$PROMPT_COMMAND; "}_wezterm_osc7 ;;
    esac
fi
```

- [ ] **Step 2: 在 Windows 端 commit + push**

```bash
git add .chezmoitemplates/bashrc/linux
git commit -m "feat(bashrc): emit OSC 7 in WSL bash for WezTerm cwd inheritance"
git push origin main
```

- [ ] **Step 3: 進 WSL 拉 + 套用**

```powershell
wsl -d Ubuntu
```

WSL 內：
```bash
chezmoi update  # 等同 git pull + chezmoi apply
```

- [ ] **Step 4: 驗證**

從 WezTerm 新開 WSL pane，cd 到目錄，duplicate pane → 應在同目錄。確認 `~/.bashrc` 有最新內容：
```bash
grep wezterm_osc7 ~/.bashrc
```

## Task 15: 加 wezterm 進 scoop installer

**Files:**
- Modify: `D:\ws\github\dotfiles\run_once_install-cli-tools.ps1.tmpl`

- [ ] **Step 1: 加一個 section**

在 `# ── Network ──` 之前或合適位置加：
```powershell
# ── Terminal ────────────────────────────────────────────────────────────
Install-ScoopPackage "wezterm"
```

注意：`Install-ScoopPackage` 用 `Get-Command $Name` 偵測；確認 `wezterm` 是 scoop 安裝後在 PATH 的命令名。

- [ ] **Step 2: 驗證 chezmoi diff（純 idempotent，安裝過所以不會跑）**

```powershell
chezmoi diff run_once_install-cli-tools.ps1
```

確認 patch 內容正確。`run_once` 已執行過所以不會重跑，不影響當前機器。

- [ ] **Step 3: Commit + Push**

```bash
git add run_once_install-cli-tools.ps1.tmpl
git commit -m "feat(install): add wezterm to scoop CLI tools installer"
git push origin main
```

## Task 16: 寫使用文件

**Files:**
- Create: `D:\ws\github\dotfiles\docs\wezterm-setup.md`

⚠️ **這份文件是「跨機器/別人接手」唯一的參考來源**——所有設定細節、安裝步驟、troubleshooting、Task 18 弄成功的 context menu 註冊方法，都要寫進來。memory 只放本機個人決策脈絡，不該重複。

- [ ] **Step 1: 寫 setup 文件**

Write `D:\ws\github\dotfiles\docs\wezterm-setup.md`:
```markdown
# WezTerm 設定指南

## 概述

本機從 Windows Terminal 遷移到 WezTerm，主要動機是 WT 的 split pane 不支援「切換 profile + 繼承 cwd」（見 [WT 限制](#wt-限制)）。WezTerm 透過 OSC 7 + SpawnCommand 預設行為達成這個需求。

## 安裝

```powershell
scoop bucket add extras
scoop install wezterm
```

新機器 bootstrap：dotfiles 的 `run_once_install-cli-tools.ps1.tmpl` 會自動裝。

## 設定檔位置

- chezmoi source: `dot_config/wezterm/wezterm.lua.tmpl`
- 部署到: `~/.config/wezterm/wezterm.lua`
- WezTerm 也會讀 `~/.wezterm.lua`，但本專案統一用 `.config/wezterm/`

## Profile 對應

| WT Profile | WezTerm 對應 | Launch keybinding |
|---|---|---|
| PowerShell 7 | `pwsh.exe -NoLogo`（default_prog） | `Ctrl+Alt+P`（split） |
| Git Bash | `~/scoop/apps/git/current/bin/bash.exe -l` | `Ctrl+Alt+B`（split） |
| Ubuntu (WSL) | `WSL:Ubuntu*` domain（prefix match） | `Ctrl+Alt+U`（split） |

## Keybindings

| Keys | Action |
|---|---|
| `Ctrl+Alt+P` | Split pane Auto → PowerShell（繼承 cwd） |
| `Ctrl+Alt+B` | Split pane Auto → Git Bash（繼承 cwd） |
| `Ctrl+Alt+U` | Split pane Auto → WSL Ubuntu（繼承 cwd） |
| `Alt+Shift+Plus` | Split pane Right → 同 profile + 同 cwd |
| `Alt+Shift+Minus` | Split pane Down → 同 profile + 同 cwd |
| `Alt+Shift+方向鍵` | Resize pane |
| `Ctrl+C` / `Ctrl+V` | Copy / Paste |
| `Ctrl+Shift+T` | New tab |
| `Ctrl+Shift+Space` | Launch menu |
| `Ctrl+Shift+R` | Reload config |

## OSC 7 cwd 繼承機制

WezTerm 用 OSC 7 escape sequence 知道每個 pane 的當前目錄。三個 shell 分別在 prompt hook 內 emit OSC 7：

- **PowerShell**: `Documents/exact__shared-profile.d/91-wezterm-osc7.ps1`（與 starship PreCommand wrap 整合，與 OSC 9;9 共存）
- **Git Bash**: `.chezmoitemplates/bashrc/windows`（PROMPT_COMMAND，含 idempotent guard）
- **WSL bash**: `.chezmoitemplates/bashrc/linux`（PROMPT_COMMAND，含 idempotent guard）

每個 shell 都有 `_wezterm_osc7` 防重複掛載 guard，多次 source `.bashrc` 不會累積。

## Explorer 右鍵「在 WezTerm 開啟」context menu

（Task 18 完成後填入實際使用的方法——可能是 wezterm 內建命令、scoop hook 腳本、或手動 reg add）

## 跨 WSL/Windows 的 cwd 限制

從 WSL pane 切到 Windows shell（PS/Git Bash），如果當前在 `/home/user`（沒有 Windows 對應路徑），新 pane 會 fallback 到該 shell 的 default cwd。要能繼承的話，需要在 `/mnt/<drive>/...` 下工作。

## WT 限制

WT 的 `splitMode: "duplicate"` 在 [`TerminalPage.cpp`](https://github.com/microsoft/terminal/blob/main/src/cascadia/TerminalApp/TerminalPage.cpp) 第 3601-3619 行的實作會強制使用當前 pane 的 profile 並完全忽略 `profile` 參數。這代表「指定 profile + 繼承 cwd」不可能透過 keybinding 實現。

## 退回 WT

WT 的 chezmoi 設定 (`run_onchange_configure-windows-terminal.ps1.tmpl`) 還在，沒被移除。把預設 terminal handler 切回 WT 即可恢復。

## Troubleshooting

### Ctrl+C 沒辦法送中斷訊號
WezTerm 的 `CopyTo Clipboard` 沒選取時應該 fallthrough 給 shell。如果壞了，把 `~/.config/wezterm/wezterm.lua` 內的 `key = 'c', mods = 'CTRL'` 改成 `mods = 'CTRL|SHIFT'`（用 WezTerm 預設）。

### Ctrl+Alt+U 沒反應
表示 `wsl -l -v` 偵測不到 Ubuntu* prefix 的 distro。檢查：
```powershell
wsl -l -v
```
如果你的 distro 名稱完全不是 Ubuntu 開頭（例如 Debian），要修改 `wezterm.lua` 內的 prefix-match 條件。

### OSC 7 沒生效
依 shell 檢查：
- PS: 開新 pane 看 `$PROFILE` 有 source `Profile.d\91-wezterm-osc7.ps1`，且 `Get-Command Invoke-WezTermOsc7` 不為空
- Bash: `echo $PROMPT_COMMAND` 應該包含 `_wezterm_osc7`
```

- [ ] **Step 2: Commit + Push**

```bash
git add docs/wezterm-setup.md
git commit -m "docs(wezterm): add setup and migration guide"
git push origin main
```

## Task 17: 更新 memory（不 commit）

**Files:**
- Create: `C:\Users\user\.claude\projects\D--ws-github-dotfiles\memory\project_wezterm_migration.md`
- Modify: 同目錄的 `MEMORY.md`（加 index 一行）

⚠️ **memory 只放本機個人決策脈絡**——「我哪天切的」「為什麼切」「source code 分析過程」。所有「該怎麼用」「要怎麼裝」「troubleshooting」全部寫在 `docs/wezterm-setup.md`，不要重複。

- [ ] **Step 1: 寫 memory file**

Write `C:\Users\user\.claude\projects\D--ws-github-dotfiles\memory\project_wezterm_migration.md`:
```markdown
---
name: WezTerm 遷移
description: Windows 主機 terminal 從 Windows Terminal 切換到 WezTerm；保留 WT 設定當 fallback
type: project
---

2026-04-21 起 Windows 主機主要 terminal 換成 WezTerm。

**Why:** WT 的 `splitMode: duplicate` 強制用當前 pane profile（[TerminalPage.cpp:3601-3619](https://github.com/microsoft/terminal/blob/main/src/cascadia/TerminalApp/TerminalPage.cpp)），無法做「指定 profile + 繼承 cwd」。WezTerm 用 OSC 7 + SpawnCommand 自然達成。

**How to apply:**
- 設定細節、安裝步驟、troubleshooting → `docs/wezterm-setup.md`（這份 memory 不重複）
- WT 設定 `run_onchange_configure-windows-terminal.ps1.tmpl` 保留不刪（fallback）
- 跨 WSL/Windows shell 切換時，cwd 在 `/home/user` 等 WSL-only 路徑下不繼承（fallback 到 default cwd）—— 預期行為
```

- [ ] **Step 2: 更新 MEMORY.md index**

Edit `C:\Users\user\.claude\projects\D--ws-github-dotfiles\memory\MEMORY.md`，在 `## 架構決策` 區塊加：
```markdown
- [WezTerm 遷移](project_wezterm_migration.md) — 2026-04-21 起 Windows 主機切到 WezTerm；WT 設定保留 fallback
```

- [ ] **Step 3: 不 commit**（memory 是本機用，不進 dotfiles repo）

## Task 18: 設定 Explorer 右鍵 context menu + 最終驗證

- [ ] **Step 1: 查 scoop wezterm 是否提供 context menu 註冊機制**

```powershell
scoop info wezterm
```

看 notes 區塊。很多 scoop extras package（例如 vscode、sublime）會提示「執行 install-context.reg 加右鍵選單」之類的指引。

也檢查 wezterm 安裝目錄：
```powershell
ls "$env:USERPROFILE\scoop\apps\wezterm\current\" | Select-String -Pattern "context|register|install"
```

- [ ] **Step 2: 嘗試 wezterm 內建命令**

```powershell
wezterm --help | Select-String -Pattern "context|register"
```

如果 wezterm 自己有 `register-context-menu` 之類的 subcommand，直接跑。

- [ ] **Step 3: Fallback 手動 reg add**

如果以上都沒有，用 registry 加：

```powershell
# 任意資料夾右鍵
reg add "HKCU\Software\Classes\Directory\shell\WezTerm" /ve /d "Open in WezTerm" /f
reg add "HKCU\Software\Classes\Directory\shell\WezTerm" /v "Icon" /d "$env:USERPROFILE\scoop\apps\wezterm\current\wezterm-gui.exe" /f
reg add "HKCU\Software\Classes\Directory\shell\WezTerm\command" /ve /d "`"$env:USERPROFILE\scoop\apps\wezterm\current\wezterm-gui.exe`" start --cwd `"%V`"" /f

# 資料夾背景右鍵（在資料夾內空白處）
reg add "HKCU\Software\Classes\Directory\Background\shell\WezTerm" /ve /d "Open in WezTerm" /f
reg add "HKCU\Software\Classes\Directory\Background\shell\WezTerm" /v "Icon" /d "$env:USERPROFILE\scoop\apps\wezterm\current\wezterm-gui.exe" /f
reg add "HKCU\Software\Classes\Directory\Background\shell\WezTerm\command" /ve /d "`"$env:USERPROFILE\scoop\apps\wezterm\current\wezterm-gui.exe`" start --cwd `"%V`"" /f
```

- [ ] **Step 4: Explorer 右鍵驗證**

任意資料夾右鍵 → 應該看到「Open in WezTerm」選項 → 點下去開 WezTerm 且 cwd 是該資料夾。

- [ ] **Step 5: 把成功方法寫進 docs/wezterm-setup.md 的「Explorer 右鍵」section**

回頭編輯 Task 16 的 `docs/wezterm-setup.md`，把 Step 1-3 中**實際使用**的方法（command 或 reg 內容）寫進「Explorer 右鍵『在 WezTerm 開啟』context menu」這個 section。其他機器要用同樣方法重現。

- [ ] **Step 6: 跑最後一次完整 Task 10 測試矩陣**

確保 chezmoi apply 之後行為仍與 Phase A 結束時一致。

- [ ] **Step 7: 最終 commit（如果 Task 16 docs 有更新）**

```bash
git status  # 確認沒有遺漏
git add docs/wezterm-setup.md
git commit -m "docs(wezterm): document Explorer context menu setup"
git push origin main
```

⚠️ **如果 Win11 系統預設 terminal handler 真的能設 WezTerm**（去設定 → 隱私權與安全性 → 適用於開發人員 → 終端機 看一下），順便把預設改 WezTerm，並在 docs 補一行「Win11 預設 terminal 可以設 WezTerm」。如果不行就跳過——context menu 已經能達到右鍵開啟的需求。

---

## Self-Review Checklist（Plan author 自檢）

- [x] **Spec coverage**: 6 個現有 WT 行為（appearance、windowing、copy/paste、resize、find、duplicate）+ 3 個新需求（cross-profile split with cwd）都有對應 task。✓（find/duplicate 部分已依使用者要求縮減）
- [x] **No placeholders**: 所有 task 都有實際 code/command，無 TBD/TODO。✓（Task 18 Step 5 是「實測完才能填」的合理動態 placeholder）
- [x] **Type/path consistency**: `git_bash` 變數、`ubuntu_domain_name`、`_wezterm_osc7`、`Invoke-WezTermOsc7` 等命名前後一致。✓
- [x] **跨平台**: `.chezmoiignore.tmpl` 在 Phase B Task 11 排除非 Windows。✓
- [x] **WT 不破壞**: WT chezmoi 設定保留；用戶可隨時切回。✓
- [x] **Workflow 遵守**: Phase A 全部本機驗證 → Phase B 才動 chezmoi source。✓
- [x] **Push 流程**: 每個 task commit 後 push；Task 14 明確標示依賴 Task 13 的 push。✓
- [x] **docs vs memory 分工**: docs 寫 what/how（跨機器可重現），memory 寫 why/when（本機決策）。✓

---

## Phase A 測試報告（Phase A Task 10 結束時填寫）

### 跨 profile cwd 測試矩陣
| 從 → 按 → 預期 | 通過 | 備註 |
|---|---|---|
| PS @ `D:\ws\github\dotfiles` `Ctrl+Alt+B` → Git Bash @ `/d/ws/...` | | |
| PS @ `D:\ws\github\dotfiles` `Ctrl+Alt+U` → Ubuntu @ `/mnt/d/ws/...` | | |
| Git Bash @ `/d/ws/github` `Ctrl+Alt+P` → PS @ `D:\ws\github` | | |
| Git Bash @ `/c/Users/user` `Ctrl+Alt+U` → Ubuntu @ `/mnt/c/Users/user` | | |
| Ubuntu @ `/mnt/d/ws` `Ctrl+Alt+P` → PS @ `D:\ws` | | |
| Ubuntu @ `/home/user` `Ctrl+Alt+P` → PS @ home (fallback) | | |
| Ubuntu @ `/home/user` `Ctrl+Alt+B` → Git Bash @ home (fallback) | | |

### WT 對照表勘誤
| 項目 | 通過 | 中信心調整紀錄 |
|---|---|---|
| 啟動 maximized | | |
| 字型 CaskaydiaCove | | |
| 字體大小 13 | | |
| 游標方塊 | | |
| `intenseTextStyle="all"` 對應 | | |
| Campbell 配色 | | |
| Tab 寬度視覺 | | |
| `Alt+Shift+Plus` 同 cwd | | |
| `Alt+Shift+Minus` 同 cwd | | |
| `Alt+Shift+方向鍵` resize | | |
| Ctrl+C 複製/中斷 fallthrough | | |
| Ctrl+V 貼上 | | |
| 選取不自動複製 | | |

---

## Execution Notes

### 為什麼不用 worktree
這是 dotfiles 純設定變更，沒有複雜衝突風險。`docs/superpowers/plans/` 在 `.chezmoiignore` 內不影響部署。直接在 main 分支跑。

### Push 策略
每個 task commit 完就 push origin main——使用者已確認此操作不影響原有環境。Task 14 明確依賴 Task 13 push 完成（WSL 端要 `chezmoi update` 拉最新）。

### 退場機制
任何階段失敗都可以：
1. `git restore <file>` 還原 chezmoi source
2. `chezmoi apply` 還原本機檔案到 source 一致狀態
3. 改 Win11 預設 terminal 切回 WT
4. （極端情況）`scoop uninstall wezterm`

### Cross-environment knowledge
- 「給人接手 dotfiles 該知道的」全部進 `docs/wezterm-setup.md`（會 commit）
- 「個人決策脈絡」進本機 memory（不 commit）
- 兩個地方不要重複內容
