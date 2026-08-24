## MODIFIED Requirements

### Requirement: repo slug 取自 git common dir 的父目錄

handoff 產物落點所用的 repo slug SHALL 由 `git rev-parse --path-format=absolute --git-common-dir` 去除最後一段後導出,其中 slug 化為將絕對路徑中每個 `:`、`\`、`/`、`.` 替換為 `-`。`handoff`、`pickup`、`handoff-list` 與 `arch-review` SHALL 使用同一條規則。SHALL NOT 使用 `git rev-parse --show-toplevel` 作為 slug 來源。

`--path-format=absolute` SHALL NOT 省略:未加時 git 印出的是相對於**呼叫者** cwd 的路徑,搭配 `-C <目標>` 會靜默解析成當前 repo。

`--path-format=absolute` SHALL 置於 `--git-common-dir` **之前**:該旗標僅影響其後的選項,置後靜默無效且 exit code 為 0(自 repo root 得 `.git`,自子目錄得 `../.git`,兩者皆 exit 0)。

`--git-common-dir` 的輸出另有一種合法用法:餵給 `cd "$(…)" && pwd -P`,由該慣用法自行正規化。此形式 SHALL NOT 被要求附帶 `--path-format=absolute`。因此本規則的可驗形狀為「呼叫點屬兩種合法形式之一」,而非「凡出現必附旗標」。

此規則與 `context/glossary.md` 記載的 auto-memory path-slug 規則一致,兩個系統對「同一個 repo」的定義 SHALL 對齊。

#### Scenario: normal 佈局

- **WHEN** 在 normal 佈局的 repo(`git-common-dir` 為 `<repo>/.git`)執行 `handoff`
- **THEN** slug SHALL 由 `<repo>` 導出,結果與舊規則相同,既有目錄 SHALL NOT 受影響

#### Scenario: bare+worktree 佈局收斂到容器

- **WHEN** 在 bare+worktree 佈局的任一 worktree(`git-common-dir` 為 `<repo>/.bare`)執行 `handoff`
- **THEN** slug SHALL 由 `<repo>` 容器導出,SHALL NOT 含 worktree 名稱

#### Scenario: 跨 worktree 互相可見

- **WHEN** 在 bare+worktree 佈局的 worktree A 寫出 handoff 後,於同一 repo 的 worktree B 開新 session 執行 `pickup`
- **THEN** `pickup` SHALL 解析得到該 handoff

#### Scenario: 旗標置後

- **WHEN** 算式寫成 `git rev-parse --git-common-dir --path-format=absolute`
- **THEN** git SHALL 印出相對路徑並以 exit code 0 結束 —— 失敗不出聲
- **AND** 該寫法 SHALL 視為錯誤,SHALL NOT 因外層另有 `realpath` 而保留

#### Scenario: 一致性由測試強制,不由散文提醒

- **WHEN** `home/` 下任一 skill body 或 reference 出現 `--git-common-dir` 的呼叫點
- **THEN** `tests/path-format-flag-order.test.sh` SHALL 斷言它是兩種合法形式之一,並在兩者皆不符時失敗
- **AND** 非呼叫點(散文提及旗標名)與刻意的反例 SHALL 以行內標記顯式豁免並註明理由,SHALL NOT 由測試以啟發式猜測
- **AND** 觸發該測試的 CI workflow 其 `paths:` filter SHALL 涵蓋它所掃描的目錄 —— 守衛不在它所守的檔案變動時執行,與沒有守衛等價

#### Scenario: 省略與置後是兩種錯誤

- **WHEN** 以 grep 驗證本規則
- **THEN** 只搜尋置後寫法的 grep SHALL NOT 被當作充分驗證 —— 它對「整個省略旗標」結構性失明,而該形式在 2026-08-24 實際存在於 `pickup` 中並通過了那次驗證

#### Scenario: 非 git 目錄

- **WHEN** `git rev-parse --git-common-dir` 失敗(當前目錄不在 git repo 內)
- **THEN** SHALL 退回以 `$PWD` 導出 slug,並照常寫檔

#### Scenario: 既有錯位目錄已遷移

- **WHEN** 本變更落地後檢視 `~/.agent/handoffs/`
- **THEN** SHALL NOT 存在以 worktree 名稱為尾綴的目錄(如 `*-main`、`*-add-self-service-portal`),同一 repo 的 handoff SHALL 位於單一容器 slug 目錄下
