## Why

延續 Wave 1（`2026-05-18-scoop-external-wave1`）把 chezmoi-managed scoop install 工具遷到 `.chezmoiexternal.toml`。Wave 1 處理了 5 個常駐 CLI（starship/zellij/uv/jq/ripgrep），Wave 2 收尾 6 個其他被 chezmoi `run_once_install-*.ps1.tmpl` 安裝的 CLI binary：kubectl、kubelogin、yt-dlp、hugo (extended)、nexttrace、golangci-lint。

判斷標準延續 `reference_chezmoi_external_cli_tools.md`：單檔 binary、GitHub Release（或官方 CDN）URL 穩定、SSH 場景受益。所有 6 個都通過。

Fresh-VM PATH bootstrap（`2026-05-19-fresh-vm-path-bootstrap`）已修，所以 Wave 2 不會再踩 modify_ 找不到 binary 的雷。

## What Changes

**新增 chezmoi-external entries（6 個工具）**：
- `kubectl.exe` ← `dl.k8s.io/release/v$ver/bin/windows/amd64/kubectl.exe`（裸 .exe，非 GitHub）
- `kubelogin.exe` ← GitHub Release `Azure/kubelogin`，archive `kubelogin-win-amd64.zip` 內 `bin/windows_amd64/kubelogin.exe`
- `yt-dlp.exe` ← GitHub Release `yt-dlp/yt-dlp`，裸 `yt-dlp.exe`（CalVer `YYYY.MM.DD`，無 `v` prefix）
- `hugo.exe` ← GitHub Release `gohugoio/hugo`，archive `hugo_extended_$ver_windows-amd64.zip` 內 `hugo.exe`（用 extended 版本一勞永逸）
- `nexttrace.exe` ← GitHub Release `nxtrace/NTrace-V1`，裸 `nexttrace_windows_amd64.exe`
- `golangci-lint.exe` ← GitHub Release `golangci/golangci-lint`，archive `golangci-lint-$ver-windows-amd64.zip` 內 `golangci-lint-$ver-windows-amd64/golangci-lint.exe`

**清理 scoop 安裝呼叫**：
- `run_once_install-cli-tools.ps1.tmpl`：移除 `hugo`、`hugo-extended`、`yt-dlp`、`nexttrace`、`golangci-lint`
- `run_once_install-containers.ps1.tmpl`：移除 `kubectl`、`kubelogin`

**Active migration on existing machines**：
新增 `run_once_after_migrate-scoop-wave2.ps1.tmpl`：
- `scoop uninstall <pkg>` 若該套件已存在
- **不需要** PATH 重排序——Wave 1 的 `run_once_after_migrate-scoop-to-external.ps1.tmpl` 已把 `~/.local/bin` 排在 `~/scoop/shims` 之前

**不動**：
- `dot_claude/modify_settings.json.sh.tmpl` 等使用 jq 的 modify_ scripts——Wave 1 + fresh-VM bootstrap 已涵蓋
- Wave 1 的 migration 腳本 / external entries / SSH workaround 清理

**Breaking changes**：
- 既有 Windows 機器執行 `chezmoi apply` 後，6 個工具會從 scoop 卸載並改由 `~/.local/bin/` 提供
- hugo-extended 取代 hugo 與 hugo-extended 兩個 scoop 套件——使用者若曾在 `hugo`（非 extended）依賴某些行為差異需注意；實務上 extended 是 strict superset

## Capabilities

### New Capabilities
（無）

### Modified Capabilities
- `tool-dependencies`：新增 6 條 requirement 各別涵蓋 kubectl/kubelogin/yt-dlp/hugo-extended/nexttrace/golangci-lint 在 Windows 上的 chezmoi-external 行為；同時新增 1 條涵蓋 Wave 2 一次性遷移腳本（不含 PATH 重排序，因 Wave 1 已處理）。

## Impact

**Code changes**：
- `.chezmoiexternal.toml`：新增 6 條 entries + 對應 version 變數
- `run_once_install-cli-tools.ps1.tmpl`：移除 5 行 scoop install 呼叫
- `run_once_install-containers.ps1.tmpl`：移除 2 行 scoop install 呼叫
- `run_once_after_migrate-scoop-wave2.ps1.tmpl`（新檔）：scoop uninstall（無 PATH 動作）

**Existing machine state changes**：
- scoop 卸載 7 個套件（hugo 與 hugo-extended 都會被卸——chezmoi-external 端統一用 extended）
- User PATH **不變**（Wave 1 已搞定 ordering）

**Memory updates（在 archive step 處理）**：
- `MEMORY.md` 中 "Win32-OpenSSH × Scoop SSH gotchas" 條目 scope 進一步更新（多 6 個工具脫離 scoop）
- `reference_chezmoi_external_cli_tools.md` 加入 Wave 2 條目

**Out of scope（Wave 3 / 永不）**：
- bun、gh、lazydocker、pwsh 等**非 chezmoi-managed**（使用者手動 scoop install）的工具——不在 dotfiles 責任範圍
- dos2unix（SourceForge 無 GitHub Release）
- Toolchain（python/JDK/rustup/go124/nvm）→ scoop 保留
- GUI / installer-only（lens、winget）→ scoop 保留
- **自家 release mirror**（supply-chain pinning）→ 已記為 `project_dotfiles_release_mirror.md` 規劃，等 scoop 遷完全部後做
