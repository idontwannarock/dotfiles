## Context

本 change 不引入新機制,也不改變任何部署行為。它處理的是**文件與實作之間的落差**:`claude-config` spec 內部兩條 requirement 對撞,而實作早已站在其中一邊。

因此這份 design 很薄,只記錄一個判斷與一條值得留下的判準。

## Goals / Non-Goals

**Goals:**

- 讓 `claude-config` spec 成為可信的權威來源:讀它不會得到互相矛盾的指示。
- 把「為何這些目錄不用 `exact_`」的理由寫進 spec,而不只是移除矛盾。移除矛盾能止血,寫下理由才能防止復發。

**Non-Goals:**

- 不改變任何 `home/dot_claude/` 的檔名前綴或部署行為。`chezmoi apply` 的產出在本 change 前後 byte-identical。
- 不清理 `.chezmoiremove` 既有內容。
- 不動 `exact_agents/` —— 它滿足 `exact_` 的前提。

## Decisions

### D1. 修正方向為「spec 追上實作」,而非反向

兩條 requirement 對撞時,以實作為準的理由不是「實作比較新」,而是**實作這一側有結構性理由支撐**:`~/.claude/commands/` 與 `~/.claude/skills/` 存在非 chezmoi 管理的檔案(本機實測 3 個:`git/amend.md`、`git/push.md`、`git/undo.md`),`exact_` 會靜默刪除它們。

*替代方案:* 改實作以符合舊 spec(把 `commands/` 改成 `exact_commands/`)—— 否決,那會在下次 apply 刪掉上述檔案,而且問題會反覆出現:只要有任何工具或人往這些目錄寫檔,`exact_` 就會與之衝突。

### D2. 不只刪除矛盾,還要寫下判準

被移除的舊 requirement 若只是消失,未來有人看到「`commands/` 沒有自動修剪」很可能把它「修好」成 `exact_`。因此在保留的 requirement 中加入一條 Scenario 明文拒絕該提議,並說明理由。

<!-- evergreen-candidate -->
**`exact_` 的適用前提**:chezmoi 的 `exact_` 前綴宣告「此目錄的內容完全屬於 chezmoi」,apply 時會刪除目錄中所有未被管理的檔案。因此它只適用於 chezmoi 獨佔的目錄(如 `exact_agents/`);凡是可能被 plugin、其他工具或使用者手動寫入的目錄(`~/.claude/commands/`、`~/.claude/skills/`),SHALL NOT 使用 `exact_`,退役項改以 `.chezmoiremove` 點名。判斷方式:`comm -13 <(chezmoi managed)  <(實際檔案列表)` 若非空,前提就不成立。

### D3. 一併擴及 skills

原 requirement 只提 commands,但 `skills/` 同屬非 `exact_` 目錄、同一套推理、同樣的退役風險。既然正在改這條 requirement,把 skills 納入的邊際成本為零;不納入則留下同一個坑的另一半。

## Risks / Trade-offs

- **[純文件變更,無測試可驗]** 本 change 不改行為,所以沒有能變紅的測試 → 驗證方式為:`chezmoi apply` 前後產出比對(應無差異)、`openspec validate`、以及 spec 內不再存在互相矛盾的敘述(grep 檢查)。
- **[判準寫在 spec 而非只在 project.md]** 略有重複風險 → spec 記載的是「claude-config 這個 capability 的行為契約」,project.md 記載的是「跨 capability 反覆適用的原則」;兩者角度不同,可並存。

## Open Questions

無。
