---
type: Reference
title: 詞彙表
description: "本專案的 domain 詞彙:chezmoi 模型、Git 工作區、開發流程、跨工具部署、承載物與自動化五組術語的定義與運作方式。"
---

# 詞彙表

**chezmoi 模型**

- **source of truth vs live config** — repo 是權威;機器上的設定是 render 產物。變更一律「先在機器上測 → 確認生效 → 才回寫 source」。
- **`.chezmoiroot`** — 指定 `home/` 為 chezmoi source root;其餘(`openspec/`、`docs/`、`tests/`、`tools/`、CI)在 chezmoi 視野外。這條分界是**雙向**的:要在使用者機器上執行的東西一律放 `home/` 之下,root 只放不部署的專案基礎建設。root 出現看似要被執行的腳本目錄,本身就是設計錯誤的徵兆——曾有一支 `scripts/scoop-interactive-update.ps1` 放在 root,alias 卻指向 `~/.local/bin/`,那個路徑永遠不會存在。
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

- **cross-tool parity / name-map wrapper** — 同一份 skill/reference body 部署到多個 AI 工具,做法是 chezmoi shared body + 每工具一個薄的 name-map wrapper。**目標工具是 Claude 與 Codex**(未來或加 Antigravity CLI);**Gemini CLI 已放棄,不要去檢查它。** 頂層 instruction file 這條鏈的權威 body 是 `home/.chezmoitemplates/user-system-prompt.md`,兩個薄指標 `home/dot_claude/CLAUDE.md.tmpl` 與 `home/dot_codex/AGENTS.md.tmpl` 除標題外各只有一行 `{{ template }}` 取用它;body 之外的共用知識走 **`~/.agent` shared body**,同樣由各工具指過去而非複製。
- **pickup 契約** — `~/.agent/handoffs/<repo-slug>/<ID>.md` 下的文檔只要含 `## Suggested skills` 與 `## Next steps` 兩段,就能被 `/pickup` 接手;`pickup` 的檔案解析是格式無關的(依檔名 glob),其餘內容形狀自由。這使該目錄不只承載 session state —— `arch-review` 的體檢報告即靠此共用同一套基礎建設,不必發明第二種產物格式。註:`## Suggested skills` 若無內容,要寫成非 bullet 的句子;`- None` 與真實條目無法區分,pickup 會去呼叫它。兩段皆為**寫入端**的硬性要求,`handoff` 在寫檔前自我檢查;`## Next steps` 每條還要帶可驗證的成功判準,否則 pickup 的封存收尾無從舉證。`<repo-slug>` 依 **auto-memory / path-slug** 的同一條規則導出,故 bare+worktree 的所有 worktree 共用一格。
- **handoff 生命週期** — `~/.agent/handoffs/<repo-slug>/` 同時是待辦清單:`handoff` 寫入、`handoff-list` 唯讀列出未封存項、`pickup` 接手並在 `## Next steps` 全數達成、使用者確認後把檔案 `mv` 進 `archive/` 子目錄。`pickup` 只 glob `<repo-slug>/*.md`,故封存項天然退出所有查找。三條紅線:不 `rm`、不由 agent 判定完成、`handoff-list` 不標註「可能已完成」候選。刻意**不與 `finish-branch` 耦合** —— 跨 repo 交接與 `arch-review` 報告不對應任何分支,綁在一起會讓它們永遠無法封存。
- **`~/.agent` shared body** — 中性、tool-agnostic 位置(`~/.agent/reference/`),由 `dot_agent/` 部署;各工具 prompt 用絕對路徑指過來,改一次全工具生效。也放 `workflow-registry.md` 與 `workflows/<slug>/active_workflows.md`。
- **兩層 context** — 知識依作用域分兩層,格式與載入時機相同(皆為 OKF bundle、皆非自動載入、需要時才讀),差別只在範圍。**machine-level** 在 `~/.agent/reference/`,跨 repo、經 chezmoi 部署到每台機器;**repo-level** 在本 repo 的 `context/`,只屬於這個 repo、不部署。判斷放哪一層:問「換一個專案還成立嗎」。
- **auto-memory / path-slug** — Claude auto-memory 統一在 `~/.claude/memory/<id>`,其中 `<id> = slug(dirname(realpath(git-common-dir)))`(絕對路徑、`/`→`-`);由 `claude-memory-seed`(SessionStart hook + 全域 post-checkout 分派)播種,含自動遷移。local-files store 共用同一把 key。

**承載物 / 自動化**

- **statusline** — Go binary(`tools/statusline/statusline.go`),由 GitHub Actions 編為 `statusline-latest` release,各平台經 chezmoi external 拉取;顯示 git diff stats、context %、rate limit、cost、worktree。
- **external-version automation** — Renovate(custom regex manager)追蹤 `.chezmoiexternal.toml` 內以 `# renovate:` 註記的釘選版本,開 bump PR(人審 + `chezmoi apply` 才落地)。
- **external-tool mirroring** — `mirror-externals.yml` 把 Renovate 追不動的上游工具(vim、jdtls、dos2unix)re-host 到本 repo 的 Releases。
- **corp-ssh** — 離線的公司伺服器 SSH 憑證/askpass 系統(AD 密碼 + TOTP);WSL + Windows 已上,macOS 延後。SSH multiplex + `PubkeyAuthentication no` 政策以 chezmoi drop-in `~/.ssh/config.d/corp-multiplex` 重現(不含 FQDN,故可入 repo;WSL/Linux/macOS only);含 FQDN/IP 的 `~/.ssh/config` host block 仍留本機,靠一行 `Include ~/.ssh/config.d/*` 接上。
- **local-files store** — 針對被 gitignore 的 `.env*` 檔的 per-repo 全域備份,checkout/worktree-add 時自動還原。
