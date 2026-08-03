## 1. 判準落地(context/ 與 spec)

先寫判準,後續每一支的分類才有依據可對照。

- [x] 1.1 改寫 `context/principles.md`「能力的部署形狀由觸發模式決定」那一條:判準改為「不可逆或外部可見」,保留 command/skill 部署形狀的說明,寫出為何「有副作用」失去鑑別力(`git/clean-gone` 刪分支卻無 flag、唯讀 review 卻鎖住)
- [x] 1.2 驗證:`context/principles.md` 無殘留「有副作用」作為判準的措辭;OKF frontmatter 的 `description` 若提及分組仍正確

## 2. 解鎖 13 支 wrapper

- [x] 2.1 移除 `.tmpl` 型 wrapper 的 flag:`handoff`、`pickup`、`handoff-list`、`arch-review`、`git/commit`、`git/sync`、`code/review-{surgical,comprehensive,linus,uncommitted}`(共 10 支)
- [x] 2.2 移除純檔案型 wrapper 的 flag:`code/review-{security,spec,types}`(共 3 支,非 `.tmpl`)
- [x] 2.2b 移除已解鎖 command 中 `description` 尾端的「Manual trigger only.」——解鎖後該句為假斷言(`handoff`、`pickup`、`handoff-list`、`arch-review`);`worklog` 兩支保留
- [x] 2.3 確認 `worklog-daily`、`worklog-team-status` 仍帶 flag,`git/clean-gone` 仍無 flag
- [x] 2.4 驗證:`grep -rl 'disable-model-invocation' home/dot_claude/commands/` 恰為 2 支且都是 worklog

## 3. commit trailer 去型號

- [x] 3.1 改 `home/.chezmoitemplates/skills/git-commit.md` 的 HEREDOC 範例,`Co-Authored-By` 改為指示用當前 model 名稱而非寫死 `Claude Opus 4.6`
- [x] 3.2 驗證:全 repo 無其他寫死模型型號的 trailer 範本(`grep -rn 'Co-Authored-By' home/`)

## 4. 部署與驗收

- [x] 4.1 `chezmoi diff` 只出現預期 hunk;**點名 target 套用**,SHALL NOT 跑裸的 `chezmoi apply`
- [x] 4.2 驗證已套用的 `~/.claude/commands/` 下,13 支無該欄位、2 支 worklog 有
- [x] 4.3 Codex 端零改動:`git diff --name-only` 不含任何 `home/dot_codex/` 路徑
- [x] 4.4 `openspec validate --all --strict` 綠燈

## 5. 機器上的孤兒 command(驗收時發現)

source 掃不到、只存在於機器上的三支 command 仍帶 flag,會讓 spec 的清單斷言在有它們的機器上不成立。

- [x] 5.1 在 `.chezmoiremove` 點名 `.claude/commands/git/{amend,push,undo}.md`,並寫出為何前次退役漏掉(只點名了 `.claude/skills/git-*` 路徑,command 目錄非 `exact_` 故不會被修剪)
- [x] 5.2 驗證:`grep -rl 'disable-model-invocation' ~/.claude/commands/` 全機恰為 2 支 worklog
