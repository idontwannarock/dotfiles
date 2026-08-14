## 1. 共用 body 加入團隊文件記錄步驟

- [x] 1.1 在 `home/.chezmoitemplates/skills/dev-workflow.md` 的小型與大型流程步驟串，於 `finish-branch` 前插入團隊文件記錄步驟的 token
- [x] 1.2 在同檔新增一段說明：判準的單一問句、Gate A/Gate B 的粒度差異、判定為否時不出聲的理由、型別交由 `doc-taxonomy` 決定
- [x] 1.3 在該段說明中寫出兩處顯性退化（本端無 Atlassian MCP、目標 space 尚未支援）
- [x] 1.4 句型須讓 Claude 端（skill 名）與 Codex 端（退化句）代入後都讀得通；單一 token 撐不住時拆成兩個 token
      → 拆成兩個 token：`teamDoc`（skill 名）與 `teamDocGap`（各端能力陳述）。流程圖那行改用 tool-neutral 字面標籤 `[team-doc step]`，不吃 token。

## 2. 兩端 name-map

- [x] 2.1 `home/dot_claude/skills/dev-workflow/SKILL.md.tmpl` 加入新 token，值為 `confluence-team-doc`
- [x] 2.2 `home/dot_codex/skills/dev-workflow/SKILL.md.tmpl` 加入同名 token，值為明說的退化文字
- [x] 2.3 驗證：`chezmoi execute-template` 分別渲染兩端 SKILL.md，斷言新 token 渲染後非空字串（blocked by 2.1, 2.2）
      → 兩端皆通過：`teamDocGap` 渲染 62 / 227 字元，`teamDoc` 兩端皆非空。

## 3. Spec 同步

- [x] 3.1 `openspec validate dev-workflow-confluence-step` 通過（已於 specs 階段確認，實作後複驗）
- [x] 3.2 確認 `workflow-concurrency` 的 `Doc Target` 欄語意與 `workflow-instructions` 的 lazy 詢問行為兩份 spec 不重複敘述同一條規則，只留單向指路
      → 已移除 `workflow-concurrency` 中重複的「不再重複詢問」斷言，改為單向指路。
- [x] 3.3 於 sync-specs 階段更新 `workflow-concurrency` 的 `## Purpose`：現行措辭為「併發追蹤機制」，未涵蓋 repo 級的文件目標綁定（delta spec 不承載 Purpose，只能在 sync 時改）
      → 已改為「per-repo 狀態載體」。同時發現 delta 漏涵蓋 `Code review 必做` 的「Review 通過 → 直接 finish-branch」scenario 與新步驟衝突，已補進 delta 再同步。

## 4. 驗收

- [x] 4.1 兩端渲染後的 SKILL.md 各自人工讀過一次，確認步驟串與說明段落語意正確、無空 token 殘留
- [x] 4.2 全文搜尋 corp 網域，命中為零
      → 0 命中。註記：corp 網域字面本就不在公開 repo 內，此處掃的是代理 pattern，證明的是「未新增疑似 corp 識別資訊」。
- [x] 4.3 以本 repo 自測：`~/.agent/workflow-registry.md` 的 dotfiles 列 `Doc Target` 留空，確認流程開始時不詢問
