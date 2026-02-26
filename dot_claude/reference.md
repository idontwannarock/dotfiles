# Claude Code 速查手冊

按需查閱。CLAUDE.md 流程中遇到不確定該用什麼工具時，來這裡找。

---

## Commands（`/command` 觸發）

### Git 操作 — `git:*`

| 指令 | 用途 |
|------|------|
| `git:sync` | fetch + rebase on main，開工前同步 |
| `git:commit` | 智慧 staging + 自動生成 commit message |
| `git:push` | 推送，自動設定 upstream |
| `git:amend` | 修改上一個 commit（未 push 才安全） |
| `git:undo` | soft reset 上一個 commit |
| `git:clean-gone` | 清理 remote 已刪除的本地分支 |

### Code Review — `code:review-*`

所有指令支援：`/code:review-* [PR number | branch | commit range]`
無引數時自動偵測：staged → unstaged → HEAD

| 指令 | 組成 | 適合情境 |
|------|------|----------|
| `code:review-quick` | 1 agent: code-reviewer | 快速檢查、小改動 |
| `code:review-full` | 4 agent 平行: code-reviewer + silent-failure-hunter + test-analyzer + linus-torvalds | 完整 review、重要功能 |
| `code:review-spec` | 3 agent: code-reviewer + linus-torvalds + test-analyzer（帶 OpenSpec context） | 確認實作符合需求 |
| `code:review-linus` | 1 agent: linus-torvalds | 架構簡潔性、good taste |
| `code:review-security` | 2 agent: silent-failure-hunter + code-reviewer（安全焦點） | 安全敏感的改動 |
| `code:review-types` | 1 agent: type-design-analyzer | 新增/修改型別定義 |

### 其他

| 指令 | 用途 |
|------|------|
| `ensure-openspec` | 初始化專案的 OpenSpec 設定 |

---

## Skills（自動觸發，不需手動呼叫）

### 核心流程 Skills — `opsx:*`

由 CLAUDE.md 流程驅動，按順序使用：

| Skill | 流程中的角色 |
|-------|-------------|
| `opsx:ff` | 小型流程：一次產生所有 artifact |
| `opsx:new` | 大型流程：建立新 change |
| `opsx:continue` | 大型流程：逐步產生下一個 artifact |
| `opsx:apply` | 根據 artifact 實作程式碼 |
| `opsx:verify` | 驗證實作符合 artifact |
| `opsx:archive` | 歸檔已完成的 change |

### 情境觸發 Skills — `superpowers:*`

視情況自動引入，不需手動觸發：

| Skill | 何時觸發 |
|-------|----------|
| `superpowers:brainstorming` | 開始任何創作性工作前 |
| `superpowers:writing-plans` | 有 spec 需要拆成實作步驟時 |
| `superpowers:test-driven-development` | 實作功能或修 bug（RED → GREEN → REFACTOR） |
| `superpowers:systematic-debugging` | 遇到 bug、測試失敗、非預期行為 |
| `superpowers:verification-before-completion` | 宣告完成前，跑驗證確認 |
| `superpowers:using-git-worktrees` | 需要隔離工作區（大型任務、避免影響主分支） |
| `superpowers:subagent-driven-development` | 任務間獨立、可平行處理 |
| `superpowers:dispatching-parallel-agents` | 多個不相關任務需同時進行 |
| `superpowers:requesting-code-review` | 完成實作後、merge 前 |
| `superpowers:receiving-code-review` | 收到 code review 回饋時 |
| `superpowers:finishing-a-development-branch` | 實作完成，決定 merge/PR/保留/丟棄 |

---

## Agents（由 Task tool 派發）

需要專業能力時，用 Task tool 啟動對應 agent。每個 agent 的完整定義在 `~/.claude/agents/<name>.md`。

### Engineering（cyan）

| Agent | 何時使用 |
|-------|----------|
| `backend-architect` | 設計 API、資料庫架構、server-side 邏輯 |
| `frontend-developer` | React/Vue/Angular UI、響應式設計、前端效能 |
| `mobile-app-builder` | iOS/Android、React Native 開發 |
| `ai-engineer` | AI/ML 功能、LLM 整合、推薦系統 |
| `devops-automator` | CI/CD、雲端基礎設施、監控告警 |
| `rapid-prototyper` | MVP、快速原型、概念驗證 |
| `linus-torvalds` | Code review、架構評估（強調簡潔與 good taste） |
| `test-writer-fixer` | 寫測試、跑測試、修復失敗的測試 |

### Testing & Quality（yellow）

| Agent | 何時使用 |
|-------|----------|
| `api-tester` | API 負載測試、契約測試、安全測試 |
| `performance-benchmarker` | 效能分析、瓶頸定位、最佳化建議 |
| `test-results-analyzer` | 測試結果分析、品質指標、趨勢報告 |
| `workflow-optimizer` | 人機協作流程最佳化 |
| `tool-evaluator` | 評估新工具、框架、服務的適用性 |

### Product（purple）

| Agent | 何時使用 |
|-------|----------|
| `trend-researcher` | 市場趨勢、病毒內容、產品機會 |
| `sprint-prioritizer` | Sprint 規劃、功能排序、RICE 評分 |
| `feedback-synthesizer` | 使用者回饋分析、痛點歸納 |

### Project Management（blue）

| Agent | 何時使用 |
|-------|----------|
| `experiment-tracker` | A/B 測試追蹤、實驗結果分析 |
| `project-shipper` | 上線協調、GTM 策略 |
| `studio-producer` | 跨團隊協調、資源管理 |

### Studio Operations（orange）

| Agent | 何時使用 |
|-------|----------|
| `analytics-reporter` | 數據分析、績效報告 |
| `finance-tracker` | 預算管理、成本最佳化 |
| `infrastructure-maintainer` | 系統健康、擴展、可靠性 |
| `legal-compliance-checker` | 法規遵循、隱私政策 |
| `support-responder` | 客服回應、FAQ 文件 |

### Bonus（gold）

| Agent | 何時使用 |
|-------|----------|
| `studio-coach` | 團隊激勵、效能教練 |
