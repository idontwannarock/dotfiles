## 1. SKILL.md

- [x] 1.1 在「Hardcoded coordinates」的 Folder taxonomy 表後，加註 folder 08 的 KB 索引頁：`5922357414`（`🧠 Knowledge Base 索引`）—— 通用 KB 須登記於此、為通用 KB 的 hub；專案 KB 仍由專案 hub 索引
- [x] 1.2 orchestration 清單 step 7（現為 L72「Update project hub index」）標籤改為「Update the index (project hub **or** KB index)」
- [x] 1.3 Common mistakes 表（L86 起）增列一行：建立通用 KB 卻未登記到 KB 索引頁 → 修法：登記到 `5922357414` 對應 Topic 分節後才算完成

## 2. references/workflow.md

- [x] 2.1 Step 7 標題（現為 L107「Update project hub index (NON-SKIPPABLE)」）改為「Update the index: project hub OR KB index (NON-SKIPPABLE)」，開頭加「Which index?」分支：專案文件 → 專案 hub；通用 KB → KB 索引頁 `5922357414`（在對應 `[Topic]` `<h2>` 下加連結，無該 topic 則新增 `<h2>`，事後 re-read 驗證）；同樣 non-skippable
- [x] 2.2 Step 7 section-mapping 的 `[KB]` 列（現為 L116「`[KB]` → "## Knowledge Base / Notes"」）拆為：專案 KB → 專案 hub 的 "## Knowledge Base / Notes"；通用 KB → KB 索引頁的 `[Topic]` `<h2>`（非專案 hub）
- [x] 2.3 Step 2（Classify）補一行：通用 `[KB]`（passes KB litmus、不指單一專案）為單頁，其索引目標是 KB 索引頁（step 7），非專案 hub

## 3. references/doc-taxonomy.md

- [x] 3.1 `[KB] topic scope` 段落（現為 L47 起）末補：通用 KB 登記於 KB 索引頁（folder 08），按 `[Topic]` `<h2>` 分組；同一 `[Topic]` 約 5 頁以上升級為 08 下的子資料夾（惰性，避免孤兒資料夾）；`[Topic]` bracket 為分組鍵

## 4. references/page-anatomy.md

- [x] 4.1 新增「KB 索引頁 anatomy」小節（實作為 **§9**，接在檔尾。§1/§3/§4 是 SKILL.md 與 workflow.md 的交叉引用鍵，插在中間會逼三份檔案一起改編號）：頂部 `panel-info`（維護規則）、每 Topic 一個 `<h2>` + 連結 bullet、trailing `panel-note`「待整理」列出 08 尚未分類頁（參照 `5922357414` 現有版型）

## 5. 驗證

- [x] 5.1 `grep -rn 5922357414 home/dot_claude/skills/confluence-team-doc/` 顯示 SKILL.md 與 workflow.md 皆含索引頁 ID
- [x] 5.2 通讀 workflow.md：建立通用 KB 的流程以更新 `5922357414` 收尾
- [x] 5.3 `chezmoi diff` 確認四份 `.md` 將重新部署到 `~/.claude/skills/confluence-team-doc/`

> **Follow-up（不屬本變更，另行追蹤）** —— 既有 Confluence 頁面清理：
> `[KB] 認證型 API…`(5895946242) 補 `[HTTP]` topic bracket；`LiveKit (Knowledge Base)`(5758386246) → `[KB][LiveKit] …`（去 deprecated 後綴）；`[KB] Support Chat`(5805867055) / `[KB] Customer Chat`(5805310028) 重分類為專案 KB 並移至各專案 hub；legacy 無前綴筆記（Explain query and optimise、Alter table charset and collation）補 `[TYPE]` 或搬移。KB 索引頁的「待整理」區已列出這些。
