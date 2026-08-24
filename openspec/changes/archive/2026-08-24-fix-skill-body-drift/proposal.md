## Why

三處敘述失準都已在 #118 那一輪實測到，且都屬於「讀起來合理、執行起來錯」的類型：`dev-workflow.md`
全篇裸寫 `context/`，在滿眼 `openspec/` 的流程文脈裡被讀成 `openspec/context/`（已在另一個 repo 造成實際
漂移）；`review-cross-model.md` 的 Step 4 狀態表把「對造停在自己的信任／授權提示」歸進成功路徑；
`repo-identity.md` 的錨點算式把 `--path-format=absolute` 寫在 `--git-common-dir` 之後，而置後靜默無效
且 exit 0——現在只因外包了一層 `realpath` 才沒出事。三者共通點是失敗不會出聲，所以不修就會一直複製出去。

## What Changes

- `home/.chezmoitemplates/skills/dev-workflow.md`：七處裸 `context/` 全部帶上「repo root 的」錨點。
- `home/.chezmoitemplates/skills/review-cross-model.md`：Step 4 狀態表新增「對造自身的信任／授權提示
  被 herdr 回報成 `done`」一列並導向 blocked 處置；並註明 `agent get` 在 agent 已退出後仍回報 `idle`，
  故 findings 檔是完成與否的唯一證據。
- `home/dot_agent/reference/repo-identity.md`：錨點算式改為旗標置前
  （`git rev-parse --path-format=absolute --git-common-dir`），並記下置後靜默無效且 exit 0 的理由。
- 全 repo grep 確認沒有別處抄了置後寫法（已確認：handoff、handoff-list、arch-review、dev-workflow、
  coordinate 五支 skill body 皆已置前，錯的只有正典本身）。

不含：`openspec/specs/project-context/spec.md` 不改——它已明寫 repo root，漂的是 body 不是 spec。
不含：跨 repo 的另一半（`mms_product_grouping_api` 已漂成 `openspec/context/`），依規則另開 handoff。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `cross-model-review`: 「收斂判定區分 blocked」新增兩條——對造自身的信任／授權提示會被回報成收斂狀態；
  agent 退出後狀態仍回報 `idle`，故狀態不得作為完成證據，findings 檔是唯一證據。
- `session-handoff`: 「repo slug 取自 git common dir 的父目錄」補上旗標順序要求——`--path-format=absolute`
  SHALL 置於 `--git-common-dir` 之前；置後靜默無效且 exit code 為 0。

## Impact

- `home/.chezmoitemplates/skills/dev-workflow.md`、`review-cross-model.md`
- `home/dot_agent/reference/repo-identity.md`
- 兩支 spec 的 delta：`cross-model-review`、`session-handoff`
- 純文件／指令敘述變更，無程式碼、無 chezmoi 套用行為改變（三檔皆非 `modify_`／`run_` 腳本）
