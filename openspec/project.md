# Project Context

> 給「做需求分析」時進入狀況用的長青背景文件。model-agnostic、人可讀。
>
> **邊界**:這裡放專案的 *為什麼存在、怎麼想這個 domain、有哪些反覆適用的原則*。
> 「系統現在做什麼(WHAT、可驗收)」在 `openspec/specs/`;「某次 change 當下的方案選擇」在該 change 的 `design.md`。三者不重疊。

## 這是什麼

跨平台的**個人** dotfiles 專案,單一使用者、多台機器(Windows / macOS / Linux-WSL),透過 [chezmoi](https://www.chezmoi.io/) 同步。

核心問題:讓一個人的 shell / editor / AI 工具 / toolchain / 開發流程設定,在異質 OS 間可重現、保持同步,並有一條文件化的 fresh-machine bootstrap 路徑。

除了靜態 dotfiles,它還承載:工具安裝與 provisioning 腳本、外部 binary 版本追蹤(Renovate)、一支 Go 寫的 statusline、GitHub Actions,以及一套自家、跨 AI 工具共用的開發流程系統(OpenSpec + discipline skills)。

**最重要的心智模型:這個 repo 是 source of truth,不是當前機器上生效的設定。** 編輯 repo 不會改動當前機器;改動當前機器也不會自動回寫 repo。機器上看到的是 source 被 render 出來的**產物**。

## 詞彙表

**chezmoi 模型**

- **source of truth vs live config** — repo 是權威;機器上的設定是 render 產物。變更一律「先在機器上測 → 確認生效 → 才回寫 source」。
- **`.chezmoiroot`** — 指定 `home/` 為 chezmoi source root;其餘(`openspec/`、`docs/`、`tests/`、CI)在 chezmoi 視野外。
- **檔名前綴(語意 load-bearing)** — `dot_`→`.`;`exact_` 目錄=內容精確鏡射(刪除會傳播);`run_`=每次 apply 都跑、`run_once_`=只跑一次、`run_onchange_`=內容變才跑;`run_after_`、`modify_`、`executable_`、`.tmpl`(Go 模板)。選錯前綴 = 行為錯(例:Rust toolchain 要每次更新必須用純 `run_`)。
- **`.chezmoitemplates/`(shared body)** — 可重用的模板片段,依平台/檔名組織(如 `bashrc/linux`);也放 discipline skills 的共用 body(`skills/<name>.md`)。
- **`.chezmoiexternal.toml`** — 宣告從 GitHub Releases / 官方 CDN 抓進 `~/.local/{bin,opt}` 的外部 binary。
- **`.chezmoiignore`** — 把非 dotfile 路徑排除在部署外。

**Git / 工作區**

- **bare + worktree layout** — 父目錄裡有 `.bare/` 與並排的 worktree 目錄;需特殊 branch 處理(不在原地 `git switch`、以 worktree 為單位操作、不在 container 層動作)。
- **worktree** — 為某個 workflow 隔離的工作區;`worktree` / `finish-branch` skill 對 normal repo 與 bare+worktree 皆原生支援。

**開發流程**

- **discipline skills** — 六個自家 skill:`grill`、`tdd`、`diagnose`、`verify-done`、`worktree`、`finish-branch`(取代已退役的 `superpowers` plugin)。
- **dev-workflow** — 編排 skill,跑完整 OpenSpec 生命週期:選流程 → grill → spec → 實作(tdd)→ verify → review → merge。
- **OpenSpec** — spec/change 追蹤。`openspec/specs/*/spec.md` = 長青行為契約(SHALL + Scenario);*change* = 提案 delta,完成後 archive,可 `sync-specs` 摺回 main specs。

**跨工具部署**

- **cross-tool parity / name-map wrapper** — 同一份 skill/reference body 部署到多個 AI 工具(Claude + Codex),做法是 chezmoi shared body + 每工具一個薄的 name-map wrapper。
- **`~/.agent` shared body** — 中性、tool-agnostic 位置(`~/.agent/reference/`),由 `dot_agent/` 部署;各工具 prompt 用絕對路徑指過來,改一次全工具生效。也放 `workflow-registry.md` 與 `workflows/<slug>/active_workflows.md`。
- **auto-memory / path-slug** — Claude auto-memory 統一在 `~/.claude/memory/<id>`,其中 `<id> = slug(dirname(realpath(git-common-dir)))`(絕對路徑、`/`→`-`);由 `claude-memory-seed`(SessionStart hook + 全域 post-checkout 分派)播種,含自動遷移。local-files store 共用同一把 key。

**承載物 / 自動化**

- **statusline** — Go binary(`claude/statusline/statusline.go`),由 GitHub Actions 編為 `statusline-latest` release,各平台經 chezmoi external 拉取;顯示 git diff stats、context %、rate limit、cost、worktree。
- **external-version automation** — Renovate(custom regex manager)追蹤 `.chezmoiexternal.toml` 內以 `# renovate:` 註記的釘選版本,開 bump PR(人審 + `chezmoi apply` 才落地)。
- **external-tool mirroring** — `mirror-externals.yml` 把 Renovate 追不動的上游工具(vim、jdtls、dos2unix)re-host 到本 repo 的 Releases。
- **corp-ssh** — 離線的公司伺服器 SSH 憑證/askpass 系統(AD 密碼 + TOTP);WSL + Windows 已上,macOS 延後。
- **local-files store** — 針對被 gitignore 的 `.env*` 檔的 per-repo 全域備份,checkout/worktree-add 時自動還原。

## 反覆適用的原則與約束

- **Repo 是 source of truth,不是 live config。** 兩邊不自動互通。
- **先在機器上測,再回寫 source。** 固定四步:改機器上實際設定 → 確認運作 → 回寫 chezmoi source → 更新文件。(尚在「local-test-only」的項目都卡在這條沒走完。)
- **盡量跨平台。** 目標是 Windows/macOS/Linux 皆可用;平台差異用 per-platform 片段拆分,而非整份分叉。
- **跨工具 parity = shared body + 薄指標。** 權威 body 一份在 `~/.agent` / `.chezmoitemplates`,每工具一個 name-map wrapper。目標工具 = **Claude + Codex**(未來或加 Antigravity CLI);**Gemini CLI 已放棄,不要去檢查它。**
- **Codex frontmatter 要嚴格 YAML。** skill `description:` 若含 `:`/`#`/開頭 `[`{` 必須加引號;Claude 容忍、Codex 會報錯。用真的 YAML parser 驗,不要只 grep。
- **憑證只留本機、不上雲。** corp-ssh、local-files 的祕密都在本機磁碟或使用者腦中;雲端密碼管理器(cloud Bitwarden)明確排除,因為情境是單機、無跨機同步需求。
- **文件要 model-agnostic、人可讀。** reference body 放 tool-neutral 位置;專案文件描述意圖,不綁單一工具的實作。
- **Windows toolchain 脫離 Scoop。** Go/JDK/GnuPG 等從官方第一手來源經 `.chezmoiexternal.toml` / 官方安裝器 provision,搭配一次性 `run_once_after_migrate-scoop-*` 清理。
- **Windows PATH 要 SSH-safe。** Win32-OpenSSH 不展開 PATH 裡的 `%JAVA_HOME%`;用 wrapper `.cmd` shim,別把原始 JDK bin 放進 PATH。
- **自動化工具一律 gate 在人審。** Renovate / mirror workflow 只開 PR;沒有人審 + 明確 `chezmoi apply` 不落地。
- **有些機器狀態刻意不在 repo 裡。** 例:全域 `git core.hooksPath` 分派器、WSLENV 的 GitLab token、corp-ssh 金鑰的單一實體磁碟備份。這是「為什麼這個沒被重現」類驚訝的固定來源——需求分析時要記得 repo ≠ 機器全貌。

## 方位:能力面在哪

完整的能力清單與行為契約在 `openspec/specs/`(每個 capability 一個 `spec.md`)。這裡只給分組方位,細節不複製:

- **chezmoi 骨架** — `chezmoi-structure`、`shell-config`、`shell-template-split`、`powershell-config`、`claude-config`、`agent-reference-layout`
- **Provisioning / toolchain** — `tool-dependencies`、`windows-toolchain-provisioning`、`rust-toolchain-management`、`jdk-version-switching`、`gpg-provisioning`、`pwsh-msi-provisioning`
- **外部版本 / 鏡射** — `external-version-automation`、`external-tool-mirroring`
- **statusline** — `statusline-release`、`statusline-native-data`、`statusline-git-diff-stats`
- **開發流程** — `discipline-skills`、`workflow-instructions`、`workflow-concurrency`、`worklog-workflow-trigger`
- **記憶 / 本機檔案** — `claude-memory-seed`、`local-files-store`
- **上手** — `bootstrap-docs`

> 註:部分 spec 的 `## Purpose` 仍是 archive 時留下的 `TBD` 佔位;它們的真正意圖要看 requirement 內文,別引用佔位行。
