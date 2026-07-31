## REMOVED Requirements

### Requirement: project.md 為長青專案 context

**Reason**: capability 更名為 `project-context`,承載物由單一檔案 `openspec/project.md` 改為 repo root 的 `context/` OKF bundle。功能未刪除。

**Migration**: 見 `project-context` 的「repo-level project context 為 repo root 的 OKF bundle」。檔案位置由 `openspec/project.md` 改為 `context/` 下依知識性質分檔;讀取方式(需要時主動讀、非自動載入)不變。

### Requirement: 內容邊界與晉升閘門

**Reason**: 同上,隨 capability 更名遷移。三分法邊界與晉升閘門的實質內容不變。

**Migration**: 見 `project-context` 的「內容邊界與晉升閘門」。原文中所有 `project.md` 指涉改為 `context/`,並新增「晉升 SHALL 只發生於 sync/archive 階段」的明文(原僅隱含於流程 spec)。
