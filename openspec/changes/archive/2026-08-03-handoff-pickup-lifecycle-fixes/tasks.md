## 1. repo slug 規則統一(F,BREAKING)

垂直切片:規則改寫 + 兩端一致 + 磁碟遷移 + 跨 worktree 可見性驗證。其餘切片的落點都依賴這條規則,故排第一。

- [x] 1.1 改 `home/.chezmoitemplates/skills/handoff.md` 的「Compose the ID, repo slug, and path」段:slug 來源改為 `slug(dirname(realpath(git-common-dir)))`,保留 slug 化字元規則與範例,補上 bare+worktree 的範例;非 git 時退回 `$PWD`
- [x] 1.2 改 `home/.chezmoitemplates/skills/pickup.md` 的「Resolve the handoff file」段,套用同一條規則;確認解析順序(Exact ID → slug glob → date prefix → latest mtime)未動
- [x] 1.3 遷移 `~/.agent/handoffs/` 的 4 個錯位目錄:`-home-howardwang-ws-github-shoalter-ai-toolkit-{main,add-agent-sessions-collector,add-self-service-portal}` 三者合併至 `-home-howardwang-ws-github-shoalter-ai-toolkit`;`-home-howardwang-ws-hktv-tw-poc-hktv-product-category-classification-api-poc-main` 去尾綴。只 `mv` 不刪;先檢查檔名衝突,有衝突就停下回報
- [x] 1.4 驗證:在 bare+worktree repo 的兩個不同 worktree 各算一次 slug,結果相同;normal repo 的 slug 與遷移前相同

## 2. handoff 寫入端契約(B + D + E)

三件都落在同一份 body 的 Gather / Compose 段,合為一個切片。

- [x] 2.1 B:把 `handoff.md` 中指向 `~/.claude/projects/<slug>/` 的那句改為現行的 `~/.claude/memory/<id>/`(或刪除該類比句 —— slug 規則本身自足)
- [x] 2.2 B 驗證:`grep -rn 'claude/projects' home/` 確認剩餘引用僅為 `claude-memory-seed` 的遷移來源與 `bare-worktree/claude-state.md` 的 transcripts 說明,兩者維持不動
- [x] 2.3 D:compose 段明文標示 `## Suggested skills` 與 `## Next steps` 為必要段落,其餘自由;寫入 `- None` 陷阱(無內容時要用非 bullet 句子)
- [x] 2.4 D:新增寫檔前自我檢查步驟 —— 兩段皆存在,且 `## Next steps` 每條都帶可驗證的成功判準
- [x] 2.5 E:Gather 段新增「記錄本次 session 語言」;檔尾 resume 行與「Report to the user」段的輸出改為帶語言後綴(非英文 `/pickup <ID> in <lang>`,英文不加)
- [x] 2.6 驗證:照新版 body 手寫一份 handoff,兩個必要段落齊備、每條 next step 有成功判準、resume 行為 `/pickup <ID> in zh-tw`

## 3. 跨 repo 交接(C)

- [x] 3.1 改 `handoff.md` 的 Gather 段:移除「writing to the wrong repo is not [fine]」這條把跨 repo 一律當錯誤的斷言;改為目標 repo 預設當前、只由使用者明講覆寫
- [x] 3.2 `handoff.md` 新增目標解析步驟:`git -C <目標> rev-parse --git-common-dir` → 套 1.1 的 slug 規則;路徑不存在或非 git repo 時停下回報。明文寫出 SHALL NOT 使用 `~/.agent/workflow-registry.md`
- [x] 3.3 `handoff.md` 的檔案骨架:跨 repo 時 header 拆為來源 / 目標兩欄,分支欄位標註屬於來源 repo
- [x] 3.4 `handoff.md` 新增「偵測到內容屬別的 repo 時可提議、但未確認前不得改落點」的紀律,並確認它不與既有的 "No confirmation" 原則衝突(僅在跨 repo 疑慮時提議)
- [x] 3.5 更新雙 wrapper 說明 `--repo` 用法:`home/dot_claude/commands/handoff.md.tmpl` 與 `home/dot_codex/skills/handoff/SKILL.md.tmpl`(後者 frontmatter 嚴格 YAML,含冒號的 description 加引號)

## 4. pickup 封存收尾(A)

依賴 2.4 —— 沒有成功判準就無法列出達成證據。

- [x] 4.1 改 `home/.chezmoitemplates/skills/pickup.md` 的 Apply 段:新增收尾步驟,`## Next steps` 全數達成時逐條列出達成證據並詢問是否封存
- [x] 4.2 封存動作寫明為移入 `~/.agent/handoffs/<repo-slug>/archive/<ID>.md`;明文 SHALL NOT `rm`、SHALL NOT 自行判定完成、SHALL NOT 在未確認下移動
- [x] 4.3 明文寫出未全數達成時 SHALL NOT 提及封存,以及此步驟不與 `finish-branch` 耦合
- [x] 4.4 驗證:`archive/` 下的檔案不被 `pickup` 的四種解析方式撿到(現有 glob 為 `<repo-slug>/*.md`,子目錄天然排除)

## 5. 新增 handoff-list(A')

- [x] 5.1 新增 `home/.chezmoitemplates/skills/handoff-list.md`:列出指定 repo(預設當前)未封存的 handoff,每項含 ID、日期、一行 Task 摘要、next steps 條數
- [x] 5.2 body 內明文寫出三條禁令:SHALL NOT 推測完成與否、SHALL NOT 標註「可能已完成」候選、SHALL NOT 移動或刪除任何檔案;並記下理由(2026-08-03 誤刪事件)
- [x] 5.3 處理邊界:目錄不存在或無項目時明確回報無項目、不報錯;`archive/` 下的項目不出現在預設輸出
- [x] 5.4 新增雙 wrapper:`home/dot_claude/commands/handoff-list.md.tmpl` 與 `home/dot_codex/skills/handoff-list/SKILL.md.tmpl`
- [x] 5.5 檢查 `.chezmoiignore.tmpl` 與 `.chezmoiremove` 是否需要為新檔案調整(參照既有 skill 的處理方式)

## 6. 部署與驗收

- [x] 6.1 `chezmoi diff` 只出現預期 hunk;**點名 target 套用**,SHALL NOT 跑裸的 `chezmoi apply`(本機常有無關既有 drift)
- [x] 6.2 比對 `~/.claude/commands/{handoff,pickup,handoff-list}.md` 與 `~/.codex/skills/{handoff,pickup,handoff-list}/SKILL.md`,三組 body 內容兩端一致
- [x] 6.3 Codex 端 frontmatter YAML 可解析(含冒號的 description 已加引號)
- [x] 6.4 端對端:真的跑一次跨 repo handoff → 到目標 repo 開新 session → `/pickup` 接得到。紙上推演不算數
- [x] 6.5 端對端:跑一次 `handoff-list`,輸出含未封存項、不含 `archive/` 項、無完成推測標註
- [x] 6.6 `openspec validate --all --strict` 綠燈
