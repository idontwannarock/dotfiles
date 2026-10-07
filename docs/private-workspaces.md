# Private workspaces

這個 repo 是 public 的。有些設定、script、skill 不能公開，或只屬於某一家公司、某一個 side project。
這些東西放在獨立的 private repo，叫做 **workspace**。每台機器自己選要裝哪些 workspace。

實作：`home/run_after_workspaces.sh.tmpl`。測試：`tests/workspaces.test.sh`。

## 架構

```
<public repo 的上一層>/
├── dotfiles/              public（chezmoi 的 source）
├── dotfiles-<name>/       一個勾選的 workspace 一個 clone
└── ...
```

清單 repo（workspace list）**不會**留在本機。`chezmoi update` 把它 clone 到暫存目錄，讀完就刪掉。

每個 workspace 都是完整的 chezmoi source：可以用 template、`run_` script、`.chezmoiroot`、自己的
`.chezmoi.toml.tmpl` 與 `promptBoolOnce`。public repo 用另一個 chezmoi 套用它，給它自己的設定檔和狀態檔：

| 檔案 | 用途 |
|---|---|
| `~/.config/chezmoi/workspaces.json` | 本機的答案：清單 repo 網址，以及每個代號的選擇 |
| `~/.config/chezmoi/workspaces/<id>/chezmoi.toml` | 該 workspace 產生的設定 |
| `~/.config/chezmoi/workspaces/<id>/chezmoistate.boltdb` | 該 workspace 的狀態（`run_once_` 記錄） |

狀態檔一定要分開：外層的 chezmoi 在跑 `run_after_` script 時鎖住了自己的狀態檔。

## 流程

`chezmoi update`：

1. 第一次跑時，問清單 repo 的網址。留空代表這台機器不用 workspace，之後不再問。
2. 把清單 clone 到暫存目錄、檢查格式、刪掉暫存目錄。
3. 清單裡有新的代號，就問一次要不要裝。下列情況不問：
   - 已經退役（`retired = true`）的代號
   - 沒有 TTY 的時候（下次有 TTY 再問）
4. 勾選的 workspace：沒有 clone 就 clone，有就 `git pull --ff-only`。
5. 對每個勾選的 workspace 跑 `chezmoi init --apply`。`init` 會重新產生它的設定，所以它新增的 prompt 也會在這裡問。

`chezmoi apply` 只做第 5 步，不連網路。

連不到清單 repo（沒網路、沒權限）時，沿用已存的答案，照樣套用本機已有的 clone。

## 清單格式

清單 repo 的根目錄放一個 `workspaces.toml`：

```toml
schema = 2

[w1]
name    = "private"
desc    = "Personal private settings and skills"
url     = "git@github.com:<owner>/dotfiles-private.git"
retired = false
```

**每個欄位都必填，沒有預設值。** 缺欄位或多出不認得的欄位，script 都會停下來報錯。

| 欄位 | 規則 |
|---|---|
| `schema` | 目前是 `2`。比這份 checkout 認得的版本新時，script 會要你先更新 public repo。`1` 多一個 `os` 欄位，已經不再讀取。 |
| `[wN]` 代號 | 本機用代號記答案。**代號永遠不改名、不重複用**，否則舊機器的答案會對到別的 workspace。 |
| `name` | `[a-z0-9-]`。顯示在問題裡，也是 clone 目錄名稱：`dotfiles-<name>`。不能重複。 |
| `desc` | 問問題時顯示的一句說明。 |
| `url` | clone 用的網址。 |
| `retired` | `true` 代表退役。 |

### 退役一個 workspace

不要從清單刪掉那一筆，改成 `retired = true`。

- 已經裝了它的機器會停止套用，並提醒 clone 還留在哪裡。
- script **不會**刪掉它裝過的檔案。要清掉，先在那個 workspace 裡用 `.chezmoiremove` 列出要刪的檔案，
  在每台機器套用一次，再標記退役。
- 刪掉一筆會讓已經勾選它的機器看到警告。

## 本機操作

- 改變對某個 workspace 的選擇：編輯 `~/.config/chezmoi/workspaces.json`，刪掉 `answers` 裡那個代號，
  下次 `chezmoi update` 會再問一次。
- 換清單 repo：刪掉 `listRepo` 這個 key。
- 看細節：`DOTFILES_LOG_VERBOSE=1 chezmoi update`。

## Shell 函式的插座

workspace 不能改 public 產生的檔案，所以 public 留了兩個插座，讓 workspace 放自己的 shell 函式：

| Shell | workspace 放檔案的位置 | 誰載入 |
|---|---|---|
| bash / zsh | `~/.shell_common.d/*.sh` | `~/.shell_common` 的最後面，照檔名順序 |
| PowerShell 7 | `~/Documents/PowerShell/profile.d/*.ps1` | profile loader，在 `_shared-profile.d` 之後 |
| PowerShell 5 | `~/Documents/WindowsPowerShell/profile.d/*.ps1` | 同上 |

- 檔案載入時，public 的函式都已經定義好了，例如 `Get-BwSecret`。
- 不要放進 `~/Documents/_shared-profile.d/`。那是 `exact_` 目錄，public 的 `chezmoi apply` 會刪掉它不認得的檔案。
- PowerShell 的兩個 `profile.d` 要各放一份。在 workspace 裡用 `{{ include }}` 讓第二份引用第一份。
- 實例：`dotfiles-shoalter` 的 `claude-zai` 與 `glab`。

## 為什麼這樣做

- **不用 git submodule**：一個 submodule 只能對應到 `~` 底下的一個目錄；`.gitmodules` 會公開網址；
  讀不到 private repo 的機器和 CI 會在 clone 時失敗。chezmoi 作者也不建議
  （[twpayne/chezmoi#4103](https://github.com/twpayne/chezmoi/issues/4103)）。
- **不用加密後放在 public repo**（作者推薦的做法）：檔名還是公開的，而且整個 skill 都加密後就沒辦法 review diff。
- **不用 `promptBoolOnce` 記 workspace 的答案**：要問就得在設定 template 裡讀清單，而 template 沒辦法處理
  離線的情況，沒網路時 `chezmoi update` 會整個失敗。所以改由 script 問，答案存在 `workspaces.json`，
  行為一樣：每個代號只問一次。
- **清單不留在本機**：不讓每台機器都看得到所有 workspace 的名稱。本機只留下勾選的那幾個的資料，
  沒勾的只留代號。
- **清單沒有 `os` 欄位**（schema 2 拿掉了）：workspace 是照公司、專案分的，不是照 OS 分的，所以每一筆都會填三種 OS。
  跟 OS 有關的是 workspace 裡面的單一功能，由該 workspace 的 `.chezmoiignore.tmpl` 處理。
- **一個 workspace 一個 repo**：離職或結束合作時，刪掉那個 repo 就乾淨了；也可以只把一個 repo 分享給合作的人。
