## 1. bare-worktree scope 拆分

- [x] 1.1 新建 `home/dot_agent/reference/bare-worktree/scope.md`：`type: Reference` frontmatter + 原 `index.md:10-33`（`## Scope` 段）的完整內容
- [x] 1.2 縮減 `home/dot_agent/reference/bare-worktree/index.md`：`## Scope` 段換成一句話範圍摘要，並在「When to read which file」表加入 `scope.md` 一列
- [x] 1.3 驗證內容無遺漏：原 `index.md` 的 `## Scope` 段每一行皆對應到 `scope.md`（以 `git show HEAD:...` 逐行對照）
- [x] 1.4 驗證 `scope.md` frontmatter 通過 YAML parser、`type` 在既有三值內、`description` 加雙引號

## 2. spec 對齊

- [x] 2.1 把 delta spec 的 MODIFIED requirement 套用到 `openspec/specs/agent-reference-layout/spec.md`（root-index scenario 措辭改為「連目錄 vs 連檔案」規則、新增 bare-worktree scenario、requirement 內文補上摘要與連結規則）
- [x] 2.2 `openspec validate --all` 通過

## 3. 部署與驗證

- [x] 3.1 `chezmoi apply ~/.agent/reference` 後 `diff -r` 確認 source 與實機一致
- [x] 3.2 驗證全 bundle 仍合規：所有非 reserved `.md` 有合法 frontmatter、僅 root index 帶 `okf_version`、所有相對連結解析
- [x] 3.3 驗證 inbound pointer 未斷：`user-system-prompt.md` 與 skill 模板指向的 6 條 reference 路徑仍存在

## 4. commit message 修正

- [x] 4.1 `git commit --amend` 移除前一個 commit message 中「root index 讓 tdd/ 與 dev-workflow-isolation.md 變可發現」的宣稱，改為只陳述 OKF §12 對 `okf_version` 位置的要求
- [x] 4.2 確認 amend 後 commit 內容未變（僅 message 變動）
