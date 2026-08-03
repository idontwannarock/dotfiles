## 1. Vault entry(其餘工作的前提)

- [x] 1.1 在 WSL 建立 `pass` entry `gitlab/corp-token`。`pass ls gitlab` 已列出。**注意**:存入的是舊權杖;若輪替,覆寫同一 entry 即可
- [ ] 1.2 在 Windows 建立對應的 `gopass` entry。**需在 Windows 機器上執行**

## 2. glab external(可獨立驗證的完整路徑)

- [x] 2.1 `home/.chezmoiexternal.toml` 加入跨平台 `glab` entry 與 `# renovate:` 註解(`gitlab-releases` / `gitlab-org/cli` / `extractVersion` 處理 `v` 前綴),置於 windows-only `{{ if }}` 區塊之外
- [x] 2.2 `chezmoi apply` 後 `~/.local/bin/glab` 可執行,`glab --version` 回報 `1.111.0`,等於釘住的版本(原手動安裝的 1.105.0 已被取代)
- [x] 2.3 `docs/renovate.md` 記錄新增的 `gitlab-releases` datasource;`renovate-config-validator` 回報 `Config validated successfully`

## 3. bash wrapper

- [x] 3.1 `home/.chezmoitemplates/shell-common/base` 的 `claude-zai` 旁加入 `glab()`:先檢查 `GITLAB_HOST`,再依 vault → `$GITLAB_TOKEN` 解析,轉呼叫用 `command glab`
- [x] 3.2 三條路徑中兩條已實測:(b) `GITLAB_HOST` 未設定 → 明確錯誤、無網路請求;(c) vault 與 env 皆無 → 明指兩來源的錯誤。(a) 的 fallback 分支亦實測通過(`glab api version` 回 `19.2.0-ee`)
- [ ] 3.3 **待使用者於有 TTY 的 shell 驗證**:vault 讀取分支(`pass show` 需 pinentry,agent 的 Bash tool 無 TTY 會卡住),以及呼叫結束後 caller 的 `GITLAB_TOKEN` 未被汙染

## 4. PowerShell 對應版本

- [x] 4.1 新增 `home/Documents/exact__shared-profile.d/26-glab.ps1`,與 bash 版共用兩句 byte-identical 錯誤訊息,轉呼叫用 `Get-Command -CommandType Application`。已用 Windows pwsh 7 parse-check 通過,並實測 host-unset 路徑正確擋下
- [ ] 4.2 **需在 Windows 機器完整驗證**(profile 載入後的實際呼叫、gopass 讀取分支)。與 handoff `cross-tool-apply-spotcheck` 的 Windows apply 驗證合併進行

## 5. 文件與 WSLENV 收尾

- [x] 5.1 `docs/gitlab-corp-access.md`:vault entry、`GITLAB_HOST`(placeholder `gitlab.example.com`)、`WSLENV`、兩個陷阱、失敗訊息對照、已知限制、MCP 探測結論。README 文件索引補上一列
- [ ] 5.2 **需使用者手動**:機器本地設定 `GITLAB_HOST` 並加入 `WSLENV`(帶 corp FQDN,不進 repo)
- [ ] 5.3 **需使用者手動**:確認 2、3 群組驗證通過後才從 `WSLENV` 移除 `GITLAB_TOKEN`,保留 registry 變數當 fallback
- [x] 5.4 機械驗證 repo 無 corp FQDN:自 repo root 全文搜尋 corp 網域,命中零(design.md 原本引用了公司字串,已改為中性描述)
