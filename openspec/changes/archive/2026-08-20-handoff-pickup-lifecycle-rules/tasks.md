## 1. pickup:讀取端的缺口

- [x] 1.1 `Apply` 段末新增「檔案無 `## Next steps` 時」的處置:指名頂替段落、不得靜默發明、無可指名者停下來問;缺 `## Suggested skills` 同理(D 無,直接由證據推得)
- [x] 1.2 `Close out` 由 3 步變 4 步,`mv` 前插入裁決進 memory 與耐久參考用 post-archive 路徑指名兩項(D4)
- [x] 1.3 `Close out` 提問改為 ask unless standing instruction,並在 Hard rules 補「常設指示只覆蓋剛完成的那一份」(D1)
- [x] 1.4 `Resolve` 段:三個位置皆未命中時掃一次全部 slug 目錄,命中須先告知所屬 repo(D2)
- [x] 1.5 `Close out` 第 4 步:歸檔落點綁解析來源目錄而非 cwd slug(D3)

## 2. handoff:寫入端的缺口

- [x] 2.1 `Gather` 段末說明所取為快照,且須寫成快照措辭(D5)
- [x] 2.2 §4 self-check 增第 4 項:重跑 HEAD sha、handoff 目錄 `ls`、`git worktree list` 並與草稿對帳(D5)
- [x] 2.3 §2 ID bullet 註明分鐘級非唯一鍵,slug 須自身可辨識(D6)
- [x] 2.4 §2b 跨 repo resume 行寫成 `cd <target> && claude "/pickup <ID> in <lang>"`(D2)

## 3. 驗證

- [x] 3.1 四個 wrapper(Claude command × 2、Codex SKILL × 2)`chezmoi execute-template` 渲染,grep `<no value>` 須為 0 —— chezmoi-author checklist 第 10 項
- [x] 3.2 確認兩個 wrapper 皆無需改動:本次新增內容未引入任何工具專屬 token
- [x] 3.3 `openspec validate --strict` 通過
- [x] 3.4 限縮 `chezmoi apply` 至 `~/.claude/commands/{handoff,pickup}.md` 與 `~/.codex/skills/{handoff,pickup}`,不全量 apply
