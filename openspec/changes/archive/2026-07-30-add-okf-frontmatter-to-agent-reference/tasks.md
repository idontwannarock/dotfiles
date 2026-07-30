## 1. local-files 目錄拆分（唯一有檔名變動的切片）

- [x] 1.1 `git mv home/dot_agent/reference/local-files/index.md home/dot_agent/reference/local-files/store.md`，加上 `type: Reference` frontmatter，並把檔內指向 `setup.md` 的相對連結與 `../bare-worktree/index.md` 連結確認仍正確
- [x] 1.2 新建薄的 `home/dot_agent/reference/local-files/index.md`：OKF §8 格式的目錄清單（bullet + 取自各檔 `description` 的說明），指向 `store.md` 與 `setup.md`，不帶 frontmatter
- [x] 1.3 `home/dot_agent/reference/local-files/setup.md` 加 `type: Playbook` frontmatter，並把檔內「見 `index.md`」的指向改為 `store.md`
- [x] 1.4 修 `home/dot_agent/reference/bare-worktree/claude-state.md` 的 inbound 連結：`../local-files/index.md` → `../local-files/store.md`
- [x] 1.5 驗證：`grep -rn 'local-files/index.md' home/ .claude/ openspec/specs/` 無殘留指向已搬走內容的連結

## 2. 其餘 concept 檔加 frontmatter

- [x] 2.1 `bare-worktree/operating.md` → `type: Playbook`；`bare-worktree/setup.md` → `type: Playbook`
- [x] 2.2 `bare-worktree/claude-state.md` → `type: Reference`
- [x] 2.3 `dev-workflow-isolation.md` → `type: Playbook`
- [x] 2.4 `tdd/tests.md` → `type: Principle`；`tdd/mocking.md` → `type: Principle`
- [x] 2.5 驗證：8 個 concept 檔皆有可解析的 frontmatter、非空 `type`、且 `description` 值加了雙引號（逐檔以 YAML parser 檢查 frontmatter 區塊）
- [x] 2.6 驗證：`bare-worktree/index.md` 未被加上 frontmatter（reserved filename）

## 3. bundle root index

- [x] 3.1 新建 `home/dot_agent/reference/index.md`：frontmatter 僅 `okf_version: "0.2"`，內容列出 `bare-worktree/`、`local-files/`、`tdd/` 三個子目錄與 root 層的 `dev-workflow-isolation.md`，每條附說明
- [x] 3.2 驗證：root index 的每個連結目標實際存在

## 4. 部署與實機驗證

- [x] 4.1 `chezmoi diff` 確認變更範圍僅為 `~/.agent/reference/` 下的 11 個檔案，無其他家目錄檔案被牽動
      — **實測結果**：本次變更確實只涉及 `.agent/reference/` 下 11 檔，但 `chezmoi diff` 另顯示 4 個**與本變更無關的既存 drift**（`~/.codex/config.toml` 一行空白差異、`install-02-npm-tools.sh`／`update-claude-plugins.sh`／`update-rust-toolchain.sh` 三個待跑的 `run_*` 腳本）。故 4.2 改以 `chezmoi apply ~/.agent/reference` 限定範圍套用，未觸及這 4 項。
- [x] 4.2 `chezmoi apply` 後確認 `~/.agent/reference/` 實際樹狀與 source 一致（含 `store.md` 出現、舊 `index.md` 內容已換成清單）
- [x] 4.3 驗證 agent 側無退化：`worktree`、`dev-workflow`、`tdd` 三個 skill 引用的 reference 路徑仍全部存在（`bare-worktree/{index,operating,claude-state}.md`、`dev-workflow-isolation.md`、`tdd/{tests,mocking}.md`）
- [x] 4.4 確認 Claude Code 與 Codex 皆能正常載入 skill（無 frontmatter schema 衝突警告）——這批檔案不在任何 tool 的 skill/memory 目錄下，預期零影響
