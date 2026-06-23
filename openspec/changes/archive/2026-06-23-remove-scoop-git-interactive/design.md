## Context

Wave 13 後 chezmoi 本身已不依賴 scoop git。目標是讓互動環境也脫離 scoop git，使 `scoop uninstall git` 安全。

調查時發現一個關鍵假象：在被 harness/父行程定型 PATH 的 session 裡，`where git` 顯示 scoop 在前——記憶當初據此記下「git/bash/gpg/ssh 全靠 scoop」。但重建「全新登入 shell」的有效 PATH（Machine 在前、User 在後）後，真實解析為：

```
git -> C:\Program Files\Git\cmd        (Machine idx9，已勝過 scoop)
bash -> C:\Windows\System32\bash.exe   (WSL，與 scoop 無關)
sh   -> ~\scoop\shims                  (唯一仍指向 scoop)
gpg  -> ~\.local\opt\gnupg\bin         (standalone external)
ssh  -> C:\Windows\System32\OpenSSH    (Windows)
```

也就是 `git`/`gpg`/`ssh` 早已脫離 scoop。互動環境對 scoop git 真正的硬依賴只有一條：**Windows Terminal「Git Bash」profile 的 `commandline` 寫死 `~\scoop\apps\git\current\bin\bash.exe`**。

## Goals / Non-Goals

**Goals:**
- 移除互動環境對 scoop git 的最後依賴，使 `scoop uninstall git` 不破壞互動 shell 與 Git Bash 終端機。
- 卸載後 `git`/`gpg`/`ssh` 仍正常、Git Bash 分頁仍可開。

**Non-Goals:**
- 不讓互動 `bash` 改解析到 git-bash（維持 WSL；要改需動 Machine PATH，影響全機，不值得）。
- 不保留互動 `sh`（僅 scoop 提供，卸載後消失，可接受）。
- 不現在把 WT settings.json 納入 chezmoi（列為 future TODO）。

## Decisions

- **只改 WT「Git Bash」profile，不加 PATH 腳本。** `git` 已由 Machine PATH 勝出，無需重排；唯一 scoop 依賴在 WT profile。相較方案 B（把 `Git\bin` 鋪上 User PATH 以保住 `sh`），YAGNI——`sh` 互動幾乎不用，chezmoi 用絕對 bash 路徑。
- **WT profile 改 `C:\Program Files\Git\bin\bash.exe`（絕對路徑），本機手改。** WT settings.json 不在 chezmoi 管理範圍；用絕對路徑而非依賴 PATH 較穩健。
- **由我在 session 內直接執行 `scoop uninstall git`**（已動手前用模擬驗證安全）。
- **不改偵測清單的 scoop 殿後項。** 那是其他/舊機的 back-compat fallback，留著無害。

## Risks / Trade-offs

- [卸載後 `sh` 不可用] → 接受；chezmoi `.sh` 用偵測絕對路徑，不受影響；如日後需要再走方案 B。
- [模擬 PATH ≠ 真實全新 shell] → 卸載後在全新 shell 實測 `where git/gpg/ssh` 與 Git Bash 分頁，作為最終驗證。
- [其他機器無 Program Files git] → 本變更為本機操作；偵測清單仍含 scoop fallback，未動到跨機行為。

## Migration Plan

1. 本機改 WT「Git Bash」profile → 開新分頁驗證切到 Program Files。
2. `scoop uninstall git`。
3. 全新 shell 驗證 `git`/`gpg`/`ssh` 與 Git Bash 分頁。
4. 更新 memory（原 TODO 標完成 + WT chezmoi 化 future TODO）。

Rollback：`scoop install git` 並把 WT profile 路徑改回，即復原。
