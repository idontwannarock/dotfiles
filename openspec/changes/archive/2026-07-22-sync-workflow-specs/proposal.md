## Why

dev-workflow rework(2026-07-21)實際改動已上線,但 `workflow-instructions` 與 `workflow-concurrency` 兩份 spec 的部分 requirement 仍描述 rework 前的舊機制:已廢除的「推進模式(逐步確認/自動推進)」與 `opsx:propose/new/continue` 指令,以及已搬到 `~/.agent/` 的 registry / active-workflows 路徑。spec 是 source of truth,與現況脫節會誤導後續工作與新機器認知。本次讓 spec 追上已交付的 skill 現況(spec-only,無程式碼變更)。

## What Changes

- **workflow-instructions**:
  - 「確認流程」requirement 收斂為只問流程選擇(Small/Large/Skip),移除「推進模式」那一問(rework 後 dev-workflow skill 只問一項)。
  - **REMOVED**「推進模式決定 opsx 指令」requirement —— 推進模式概念與 `opsx:propose`/`opsx:new`/`opsx:continue` 指令均已不存在。
  - 「小型核心流程」body 措辭 `opsx` → `openspec`。
- **workflow-concurrency**:
  - 「Workflow Registry」路徑 `~/.claude/workflow-registry.md` → `~/.agent/workflow-registry.md`。
  - 「Active Workflows Index」位置由「project memory 下」更正為 `~/.agent/workflows/<repo-slug>/active_workflows.md`。

## Capabilities

### New Capabilities

（無)

### Modified Capabilities

- `workflow-instructions`:移除已廢除的推進模式/opsx 指令 requirement,確認流程收斂為單一提問。
- `workflow-concurrency`:registry 與 active-workflows 路徑更新為 `~/.agent/` 現況。

## Impact

- `openspec/specs/workflow-instructions/spec.md`、`openspec/specs/workflow-concurrency/spec.md`(spec-only 校準;無程式碼、無 chezmoi 腳本變更)。
- dev-workflow skill 本體已是現況,不需改動。
