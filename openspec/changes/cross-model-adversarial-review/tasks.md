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
- [ ] 1b.6 **實測 codex profile**:`--sandbox read-only --add-dir <FINDINGS_DIR>` 是否真能組合成「repo 唯讀、findings 目錄可寫、無核准提示」;驗證後才把該列標為已驗證
- [ ] 1b.7 實測 claude profile 同上;未通過者維持標示未驗證

## 2. 失敗路徑與退化可見性

blocked 由 1 依賴。此片把所有異常收斂到「軟退化 + 顯式標註 + 仍然收尾」。

- [ ] 2.1 收斂判定只採信 `idle`/`done`;`blocked`、timeout、stalled 走退化路徑
- [ ] 2.2 findings 檔缺失或為空時視為失敗,不得解讀為「無發現」
- [ ] 2.3 前置條件檢查:`HERDR_ENV` 未設、herdr 不可執行、無可用異種 kind —— 各自產生具名原因
- [ ] 2.4 退化時於報告顯著位置標註「跨模型反駁:未執行 —— <原因>」
- [ ] 2.5 失敗路徑同樣執行 `pane close` + `agent list` 確認;只關自己開的 pane
- [ ] 2.6 實作有時限的 best-effort 禮貌退出:已知 kind 送其結束指令(`blocked` 時先送 esc),逾時或未知 kind 直接跳過;無論結果 `pane close` 皆執行
- [ ] 2.7 實跑至少兩條失敗路徑(建議:herdr 不可用、對造 blocked),確認皆有標註且無殘留
- [ ] 2.8 驗證禮貌退出確有作用:比對正常退出與硬關 pane 兩種情況下,對造的 session 記錄是否完整落地

## 3. 接進 review 關卡的分級

blocked by 1。此片改動既有 review body,讓打分與反駁分工落地。

- [ ] 3.1 修改 `home/.chezmoitemplates/skills/review-comprehensive.md`:confidence 打分移至送交反駁之前,職責收斂為噪音過濾
- [ ] 3.2 對造獨立發現的 findings 走同一套打分後才納入比較
- [ ] 3.3 實作分級規則:兩造皆認可→Critical;反駁成立→降級或剔除並附理由;僅單造提出→明列為分歧交由使用者裁決
- [ ] 3.4 實跑一次完整 `review-comprehensive` + 跨模型段,確認三種分級皆能出現在報告中

## 4. 接進大型流程與清單維護

blocked by 3。

- [ ] 4.1 修改 `home/.chezmoitemplates/skills/dev-workflow.md` 的大型流程串,於 `reviewFull` 後接 `code:review-cross-model`;小型流程不動
- [ ] 4.2 在 name-map 加入新 command 的兩端名稱
- [ ] 4.3 更新 `model-invocability` 解鎖清單至 15 支,並確認「清單涵蓋整棵樹」的總數斷言仍成立
- [ ] 4.4 更新 `docs/herdr.md`:補上 `agent wait` 的 `blocked` 陷阱與「無 `agent stop` 子命令」兩項實測事實

## 5. 收尾

blocked by 4。

- [ ] 5.1 `openspec validate` 通過
- [ ] 5.2 `verify-done`:跑 repo 既有測試,確認未被本次變更影響
- [ ] 5.3 sync-specs 時對照實作檢視 design.md 的兩條長青候選,決定是否晉升 `context/`
