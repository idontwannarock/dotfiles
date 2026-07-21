# Tasks: fix-discipline-skills-review-findings

## 1. worktree skill 修正(A/B/J/Q)

- [x] 1.1 normal 命令補 `main` 起點;bare 命令改 `<branch>` 通用命名;Register 段內嵌 arch 分派(normal 自動推導 / bare 用 autoMemoryDirectory);補失敗指引(dir/branch 已存在、`mkdir -p`、`--git-dir` 需在 container)

## 2. finish-branch skill 重構(C/D)

- [x] 2.1 依 design D1 重寫:選項 × ARCH 行為表、stop-on-first-failure、dispose/row 移除僅在 merge 確認後、Keep/Push+PR 保留、Discard `-D` 確認 gate

## 3. superpowers 殘留(E/F)

- [x] 3.1 user-system-prompt 加過渡護欄一句(D5)
- [x] 3.2 run_install-04-codex-plugins.{sh,ps1}.tmpl 移除 superpowers 安裝與失真註解

## 4. 文件與 spec 收尾(G/H/M/K/L + guard I)

- [x] 4.1 operating.md Finishing 段縮成 rationale + 指向 finish-branch
- [x] 4.2 dev-workflow.md:70 sigil 反例改寫(hardcode `$openspec-…` 例)
- [x] 4.3 exact_agents/README.md:51 舊敘述、docs/claude-code.md:150 澄清、archived proposal/tasks 的 installer 敘述更正
- [x] 4.4 chezmoi-author skill checklist 加 render + grep `<no value>` guard(D4);Codex wrapper 加 user-invocable 註解(P)

## 5. Apply + 驗證

- [x] 5.1 render 全部受影響 wrappers + grep `<no value>`(新 guard 首次執行);`chezmoi apply`;grep 驗證無 superpowers 殘留於 Codex 安裝腳本渲染
- [x] 5.2 `openspec validate fix-discipline-skills-review-findings --strict`
