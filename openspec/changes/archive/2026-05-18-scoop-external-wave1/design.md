## Context

`.chezmoiexternal.toml` 已是熟成的下載管道(已部署 `statusline.exe`、`passgen.exe`、`rtk.exe`),
新增 entries 屬「同模式擴展」,沒有新概念。風險集中在三處:
(1) 既有 scoop 安裝會與 chezmoi-external 並存產生 PATH 衝突;
(2) starship/zellij 兩支已有專屬 SSH workaround,清理時必須一併處理 profile.d 邏輯;
(3) chezmoi 跨平台,本變更只動 Windows,Linux/macOS 由各自的 `run_once_install-01-runtimes.sh.tmpl` 處理,不需動。

## Goals / Non-Goals

**Goals:**
- starship / zellij / uv / jq / ripgrep 在 Windows 上完全脫離 scoop
- 既有機器執行 `chezmoi apply` 後 SSH session 立即生效(無需手動 `scoop uninstall`)
- 刪掉 `Documents/exact__shared-profile.d/35-scoop-ssh-shims.ps1`(現只含 zellij)
- 簡化 `90-prompt.ps1` 的 starship 啟動回標準寫法

**Non-Goals:**
- 處理 dos2unix(SourceForge 來源,留 Wave 1 follow-up)
- 處理 bun/gh/lazydocker/pwsh 等 Wave 2 候選工具
- 動 Linux/macOS 安裝路徑(已是非 scoop)
- 替使用者升級任何工具版本(僅遷移現用版本)

## Decisions

### D1: 版本 pinning vs `-latest` tag
**選擇:版本 pinning,用 chezmoi template 變數集中宣告。**

`.chezmoiexternal.toml` 已有 rtk 採此模式(`{{- $rtkVersion := "0.36.0" }}`);
這 5 個第三方工具同樣 pinned,變更版本就是 PR 改數字,reproducible 且可審計。

**替代方案:**
- 自建 `-latest` tag(像 statusline / passgen):需我們維護 release pipeline,3rd-party tool 不適用
- chezmoi `refreshPeriod`:會自動拉新版,但無法控制升級時機,不可預期

### D2: jq 直接下載 `.exe` vs 包進 archive
**選擇:跟著 scoop manifest 走 — jq 是裸 `.exe`,其他 4 個是 `.zip`。**

對應的 chezmoi external `type`:
- `starship` / `zellij` / `uv` / `ripgrep`: `type = "archive-file"`,設 `path = "X.exe"`(ripgrep 有 `extract_dir` 子層,`path` 設為完整子路徑)
- `jq`: `type = "file"`,直接抽

### D3: scoop uninstall 與 PATH reorder 的腳本類型
**選擇:`run_once_after_migrate-scoop-to-external.ps1.tmpl`(run_once_after_ phase)。**

`run_once_after_` 在 `.chezmoiexternal.toml` 下載完成、所有 dotfiles 部署完之後執行。
這順序保證 `~/.local/bin/starship.exe` 已存在後才 uninstall scoop 版本,避免「卸了又找不到」的 race。

腳本職責:
1. 對 5 個套件分別判斷 `scoop list <pkg>` 有沒有,若有就 `scoop uninstall <pkg>`(2>&1 抑制非 Windows 環境的 stderr)
2. 讀 `[Environment]::GetEnvironmentVariable('Path', 'User')`,split `;`
3. 若 `~/.local/bin` index > `~/scoop/shims` index,將 `~/.local/bin` 移至 `~/scoop/shims` 前
4. 寫回 User PATH(`SetEnvironmentVariable`),警告需新 session
5. 一次性 hash(`run_once_`)避免重複跑

**冪等性:**
- scoop uninstall: 已卸載再跑等同 no-op
- PATH reorder: 用「目標順序已正確就跳過」的早返
- 但 `run_once_` 機制本來就一次性,雙保險

**替代方案:**
- `run_onchange_`: 每次內容變更會重跑;但 PATH reorder 邏輯不需要 re-run
- profile.d 動態 patch PATH: 每次 session 開啟都跑,效能稅,且不會生效於 User-level env(只影響當前 session)

### D4: 35-scoop-ssh-shims.ps1 處理方式
**選擇:刪除整個檔案(`chezmoi forget`/git remove)。**

該檔案的 commit message 已明說「未來 starship/zellij 都遷出 scoop 即可刪」。Wave 1 同時遷
這兩支,殘留條件已滿足。

**注意:**
- 因 chezmoi 用 `exact__shared-profile.d/` 命名(雙底線 → 表示 exact 模式,單底線解一層),
  從 source 刪除後 chezmoi apply 會自動刪 target,不需額外清理步驟。
- chezmoi-author skill 已警示 `exact_` prefix 會「靜默刪未管理檔案」;此處我們是「source 與 target 都刪」,不踩雷。

### D5: 90-prompt.ps1 starship 簡化
**選擇:保留 `Invoke-Starship-PreCommand` (OSC 9;9 directory tracking),刪除 starship 路徑解析與 shim rewrite。**

新內容(第 14-33 行替換為):
```powershell
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell --print-full-init | Out-String)
}
```

`Get-Command starship` 會走標準 PATH 解析,經 D3 重排後解析到 `~/.local/bin/starship.exe`,
不再有 shim rewrite 的必要。

### D6: dos2unix 暫不處理的決策
**選擇:Wave 1 範圍外,scoop 繼續管。**

dos2unix 的 Windows binary 在 SourceForge,URL 形如
`https://master.dl.sourceforge.net/project/dos2unix/dos2unix/7.5.5/dos2unix-7.5.5-win64.zip`,
URL 結構穩定但非 GitHub Release(無 `latest` tag、無 API);用 chezmoi external 也技術可行,
但要寫死 dl 鏡像、可能掉到不同 mirror 失敗。Wave 1 保持簡單,follow-up 處理。

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| User PATH 修改要 new session 生效,使用者誤以為「沒效」 | 遷移腳本最後 `Write-Warning` 明確提示重開 terminal |
| scoop uninstall starship 後若 chezmoi-external 還沒下載完(極端 race) | run_once_after_ 確保 external 已下載;且我們先讀本機 `~/.local/bin/starship.exe` 存在才 uninstall |
| GitHub raw release URL 偶爾被 rate-limit(企業 NAT 共用 IP) | chezmoi external 失敗會 retry;若仍失敗,fallback 回 scoop 重裝 = 復原 |
| 3rd-party release 不會「永遠存在」(repo 被刪、tag 被改名) | pinned 版本長期可下載;若上游真消失,降到 scoop 重裝再決定 |
| ripgrep 的 archive 有子目錄,chezmoi `path` 寫錯抽不出來 | 用實測 path `ripgrep-15.1.0-x86_64-pc-windows-msvc/rg.exe`,template 內以 `$version` 變數同步 |
| Wave 1 後存在的 scoop config(`scoop config`、`scoop status`)殘留 | 不影響;scoop 仍管 70+ 套件,config 仍有用 |
| PATH 重排腳本誤刪 PATH 條目 | 用 split/filter/join,只動 `~/.local/bin` 的位置,其他條目原樣保留;有 unit-test-ish 的 dry-run 顯示 before/after |

## Migration Plan

1. **本地驗證(在 worktree 中)**:
   - `chezmoi apply --dry-run` 觀察 download 與 script 行為
   - `chezmoi apply` 實際執行,觀察:
     - `~/.local/bin/{starship,zellij,uv,jq,rg}.exe` 已存在
     - scoop 五個套件已卸載
     - User PATH 順序正確
   - 開新 PowerShell session 確認 `(Get-Command starship).Source` 指向 `~/.local/bin/starship.exe`
   - SSH 進來確認 starship prompt 顯示、zellij 啟動正常

2. **回滾路徑**(若中途出問題):
   - `scoop install starship zellij uv jq ripgrep`(重裝)
   - 手動將 `~/.local/bin` 移回 PATH 原位置(或刪掉,scoop shims 自然取回)
   - `git revert <commit>` 把 chezmoi 端改回

3. **新機器**:
   - `chezmoi apply` 自動裝 chezmoi-external 5 支;scoop 從未裝過,migration 腳本判斷 `scoop list` 無資料則 no-op,PATH reorder 仍跑(若該機 `~/.local/bin` 也未在 PATH,腳本 prepend 之)

## Open Questions

1. **`run_once_` hash 與遷移腳本** — 若 Wave 2 加更多工具,複用同支腳本?還是 Wave 2 另開新 `run_once_`? 傾向新開,因為 Wave 1 完成後遷移腳本內容不再變動,留它不要動。
2. **是否一併把 `~/.local/bin` 加入 PATH 的新機器初始化?** — 目前邏輯假設 PATH 中已有此條目(從歷史機器繼承)。新機器若連 `~/.local/bin` 都不在 PATH,腳本要 prepend 而非 reorder。建議:腳本邏輯改為「目標位置 OR not-in-PATH → prepend」。
