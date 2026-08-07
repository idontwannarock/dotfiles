## 1. Tracer bullet:一條完整的派工→讀檔→收尾

窄但完整穿過所有層 —— shared body、雙工具 wrapper、chezmoi 部署、herdr 派工序列、檔案資料通道、生命週期收尾。此片完成後,`code:review-cross-model` 在本機可實際跑出一次成功往返。

- [x] 1.1 撰寫 shared body `home/.chezmoitemplates/skills/review-cross-model.md`:對造 kind 選擇規則(異於當前工具)、上下文邊界(僅 branch/commit range + repo 路徑)、唯讀邊界聲明、findings 檔輸出路徑約定
- [x] 1.2 撰寫 Claude 端 wrapper `home/dot_claude/commands/code/review-cross-model.md.tmpl`(不含 `disable-model-invocation`)與 Codex 端 `home/dot_codex/skills/review-cross-model/SKILL.md.tmpl`(description 含冒號者加引號)
- [x] 1.3 在 body 中實作 herdr 序列:`pane split --no-focus` → `agent start --kind <異種>` → `agent prompt --wait` → 自約定路徑讀 findings 檔 → `pane close` → `agent list` 確認無殘留;pane id 一律取自回應
- [x] 1.4 限縮範圍 `chezmoi apply` 本次子樹,驗證 `~/.claude/commands/code/review-cross-model.md` 與 `~/.codex/skills/review-cross-model/SKILL.md` 皆存在且同源;以 YAML parser 驗 Codex frontmatter
- [x] 1.5 本機端到端實跑一次成功路徑,確認 findings 檔有內容、pane 已關閉、`herdr agent list` 無殘留

## 1b. 首次實跑抓到的缺陷(對造發現,已修進 body/spec,待驗證)

- [x] 1b.1 findings/反駁路徑加消毒(branch 名含 `/` 會產生未建立的巢狀目錄)
- [x] 1b.2 補反駁的檔案通道(原本只有第一輪 findings 有通道,反駁無處可取)
- [x] 1b.3 派工前確認 `git diff <base>...<branch>` 非空,否則以 `scope not visible` 退化
- [x] 1b.4 kind-specific 的啟動參數與結束指令外置為 `~/.agent/reference/cross-model-counterparts.md`
- [x] 1b.5 body 補上「新 split 的 pane 未就緒時 `agent start` 會回 `agent_pane_busy`,需等 prompt 並重試」
- [x] 1b.6 **實測 codex profile** — `--sandbox read-only` 與 `--add-dir` 互斥;可行組合為 `--cd <FINDINGS_DIR> --sandbox workspace-write --ask-for-approval never`,三向 probe 全數如預期,該列標為已驗證
- [x] 1b.7 實測 claude profile — `--disallowedTools "Write(<repo>/**)"` **未能**擋下寫入 repo;該列標為「邊界未強制」,並補上 `acceptEdits` 不涵蓋 Bash 的實測
- [x] 1b.8 兩個 kind 皆再現「首個 prompt 被啟動通知吞掉、herdr 仍回報收斂」——body 與 spec 補上「重送一次再退化」

## 2. 失敗路徑與退化可見性

blocked 由 1 依賴。此片把所有異常收斂到「軟退化 + 顯式標註 + 仍然收尾」。

- [x] 2.1 收斂判定只採信 `idle`/`done`;`blocked`、timeout、stalled 走退化路徑
- [x] 2.2 findings 檔缺失或為空時視為失敗,不得解讀為「無發現」
- [x] 2.3 前置條件檢查:`HERDR_ENV` 未設、herdr 不可執行、無可用異種 kind —— 各自產生具名原因
- [x] 2.4 退化時於報告顯著位置標註「跨模型反駁:未執行 —— <原因>」
- [x] 2.5 失敗路徑同樣執行 `pane close` + `agent list` 確認;只關自己開的 pane
- [x] 2.6 實作有時限的 best-effort 禮貌退出:已知 kind 送其結束指令(`blocked` 時先送 esc),逾時或未知 kind 直接跳過;無論結果 `pane close` 皆執行
- [x] 2.7 實跑兩條失敗路徑:對造 blocked(以省略 approval 預授權 + 寫入 workspace 外重現)與 herdr 不可用(前置檢查兩分支);皆正確歸類、收尾無殘留、工作樹逐字相同
- [x] 2.8 驗證結果**推翻原假設**:codex 硬關 pane 前後 session 皆 14 行、結尾為完整 `task_complete`,孤兒行程 0 —— 禮貌退出對此 kind 測不到好處;design 與 body 已改為只主張「hook-bearing kind」且標明未實測

## 3. 接進 review 關卡的分級

blocked by 1。此片改動既有 review body,讓打分與反駁分工落地。

- [x] 3.1 修改 `home/.chezmoitemplates/skills/review-comprehensive.md`:confidence 打分移至送交反駁之前,職責收斂為噪音過濾
- [x] 3.2 對造獨立發現的 findings 走同一套打分後才納入比較
- [x] 3.3 實作分級規則:兩造皆認可→Critical;反駁成立→降級或剔除並附理由;僅單造提出→明列為分歧交由使用者裁決
- [x] 3.4 實跑跨模型交換與分級,三種分級皆出現(Critical 2 / Split 1 / Refuted 2);**範圍縮減**:未跑六個 lens 的 subagent fan-out,僅驗交換與分級路徑

## 3b. 跨模型 review 對本 change 自身的發現(待修)

- [x] 3b.1 **Critical** 快照既不完整也不是還原來源:雜湊只涵蓋 scope 內 tracked 檔(scope 外的髒檔改動 porcelain 不變、隱形)、untracked 內容從未雜湊、且雜湊只能偵測不能還原 —— 「restore those paths」從 git 還原會抹掉使用者未 commit 的工作
- [x] 3b.2 **Critical** claude profile 的 `Bash(git *)` 預授權涵蓋 `git reset --hard` / `git clean` 等破壞性指令
- [x] 3b.3 **Critical** 改為軟限制:優先選寫入受限的 kind,僅有不受限者仍執行但報告須揭露。實測推翻「claude 不可限制」—— cwd=repo 且不給 `--add-dir` 時,repo 外寫入會跳核准對話框而非落地(2026-08-07),先前結論是測試組態的產物
- [x] 3b.4 採 A:profile 表加 readiness 探測欄(codex `codex login status`),Step 0 於建立 pane 前執行,失敗以 `counterpart not authenticated` 退化;並明訂只記錄探測**命令**、不得留存**結果**
- [x] 3b.5 scratch 目錄在**其他 repo** 未被 gitignore:run 期間為可見的未追蹤檔,不可攔截的終止會留殘骸,併發 `git add -A` 有 staging race

## 4. 接進大型流程與清單維護

blocked by 3。

- [x] 4.1 修改 `home/.chezmoitemplates/skills/dev-workflow.md` 的大型流程串,於 `reviewFull` 後接 `code:review-cross-model`;小型流程不動
- [x] 4.2 在 name-map 加入新 command 的兩端名稱
- [x] 4.3 更新 `model-invocability` 解鎖清單至 15 支,並確認「清單涵蓋整棵樹」的總數斷言仍成立
- [x] 4.4 更新 `docs/herdr.md`:補上 `agent wait` 的 `blocked` 陷阱與「無 `agent stop` 子命令」兩項實測事實

## 5. 收尾

blocked by 4。

- [x] 5.1 `openspec validate` 通過
- [x] 5.2 `verify-done`:跑 repo 既有測試,確認未被本次變更影響
- [x] 5.3 sync-specs 時對照實作檢視 design.md 的兩條長青候選,決定是否晉升 `context/`

## 1c. 邊界改採偵測(依 Q1/Q2 的實測結論反轉 1b 的部分決策)

- [x] 1c.1 對造工作目錄改回 repo,findings 寫 `<repo>/.cross-model-review/<run id>/`
- [x] 1c.2 `.gitignore` 加入 `.cross-model-review/`
- [x] 1c.3 profile 表改寫:沙箱只負責「寫入不超出 repo」,不再宣稱對 repo 唯讀
- [x] 1c.4 body 加派工前工作樹快照,收尾加比對/還原/揭露,以及移除 scratch 目錄
- [x] 1c.5 實跑驗證:工作樹前後快照比對、scratch 移除、pane 收尾皆通過
- [x] 1c.6 實跑發現:agent 退出後 pane 回到 shell,`agent prompt` 的文字被 shell 逐行執行;body 與 spec 補上「送出前確認 agent 仍佔用 pane」
- [x] 1c.7 補跑完成:`session_meta.cwd` = `/home/howardwang/ws/github/dotfiles`(codex-cli 0.146.1)、findings 落在 `.cross-model-review/verify-run/`、收尾後工作樹逐字相同且 scratch 已移除

- [x] 2.9 退化理由集中成清單並要求回報實際命中的那一個(原本散在四個 step,措辭不一致)
