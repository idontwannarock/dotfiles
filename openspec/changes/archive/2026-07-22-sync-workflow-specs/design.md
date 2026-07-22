## Context

純 spec 校準:讓兩份 workflow spec 追上 2026-07-21 dev-workflow rework 已交付的現況。無程式碼/腳本變更,dev-workflow skill 本體已是正確狀態。

現況(已驗證):
- dev-workflow skill Step 1 只問 Small / Large / Skip,無「推進模式」。
- `grep 推進模式 / opsx:propose` 於 `~/.claude/skills/` 與 shared-body 皆無命中。
- 實際 registry:`~/.agent/workflow-registry.md`(欄位 Repo | Main Repo Path | Project Memory Path,與 spec 格式一致)。
- 實際 active-workflows:`~/.agent/workflows/<repo-slug>/active_workflows.md`(非 project memory 下)。

## Goals / Non-Goals

**Goals:**
- 移除 spec 中已不存在的推進模式/opsx 指令 requirement。
- 更新 registry / active-workflows 路徑為 `~/.agent/`。

**Non-Goals:**
- 不改 dev-workflow skill 或任何腳本(已是現況)。
- 不動 registry 的欄位格式(格式本就與現況一致,只有位置變)。

## Decisions

- **推進模式 requirement 用 REMOVED 而非 MODIFIED**:概念整個消失(不是換寫法),REMOVED 並附 Reason/Migration 最誠實。
- **確認流程用 MODIFIED**:requirement 仍在,只是從兩問收斂為一問,保留 requirement 身份。
- **archive 走正常 MODIFIED/REMOVED**:兩份主 spec 已於前一個 change(fix-spec-format-drift)補齊 `## Purpose`/`## Requirements` 標頭並使用標準 `### Requirement:` 結構,openspec 1.1.1 的 MODIFIED header 匹配可正常運作(不需再手動折入)。

## Risks / Trade-offs

- [MODIFIED 需完整貼上 requirement 全文,漏 scenario 會在 archive 時遺失細節] → 逐條從現行 spec 複製全文,只改 drift 字句。
- [archive 若仍因工具 quirk 失敗] → fallback 同前:手動折入主 spec + `--skip-specs`。

## Migration Plan

1. 寫 delta specs → `openspec validate --strict`。
2. archive 折入主 specs → `openspec validate` 兩份仍 pass。
3. commit → review → PR → merge。

## Open Questions

（無)
