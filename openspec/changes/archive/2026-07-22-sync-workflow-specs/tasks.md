## 1. Spec 校準(spec-only,無程式碼)

- [x] 1.1 workflow-instructions delta:MODIFIED 確認流程(移除推進模式)、REMOVED 推進模式決定 opsx 指令、MODIFIED 小型核心流程(opsx→openspec)
- [x] 1.2 workflow-concurrency delta:MODIFIED Workflow Registry(路徑 ~/.agent/)、MODIFIED Active Workflows Index(路徑 ~/.agent/workflows/<slug>/)

## 2. 驗收

- [x] 2.1 `openspec validate sync-workflow-specs --strict` 通過
- [x] 2.2 archive 折入主 specs(MODIFIED/REMOVED 正常匹配;失敗則手動折入 + --skip-specs)
- [x] 2.3 archive 後 `openspec validate workflow-instructions` 與 `workflow-concurrency` 仍 pass
- [x] 2.4 grep 主 specs 確認無殘留 `opsx:propose`/`opsx:new`/`opsx:continue`/`~/.claude/workflow-registry.md`/「推進模式」
