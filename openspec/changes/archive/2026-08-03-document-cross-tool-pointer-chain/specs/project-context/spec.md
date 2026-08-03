## ADDED Requirements

### Requirement: auto-memory 不承載 repo-level 長青知識

agent 的 auto-memory(`~/.claude/memory/<repo-slug>/`)SHALL NOT 作為 repo-level 長青知識的唯一載體。凡某條事實同時滿足「以本 repo 為範圍」與「跨 change 反覆適用」,它 SHALL 於 `openspec-sync-specs`／archive 階段被晉升進 `context/` 下性質相符的 concept 檔,並於晉升後回收該 memory。

理由是載體性質而非內容品質:auto-memory 是 point-in-time 觀察、不受版控、不在需求分析的閱讀路徑上,且無人審閱。同一條事實留在那裡會隨程式碼漂移而無從察覺,也不會被 `grill`／`arch-review` 讀到。

回收 SHALL 同時刪除 memory 檔與 `MEMORY.md` 中對應的索引行。只刪其一會留下斷鏈:索引指向不存在的檔案,或孤兒檔案不再可被發現。

memory 若在晉升後**仍有**未被 `context/` 涵蓋的唯一內容,SHALL 保留該檔並僅刪除已晉升的部分;整份刪除的前提是無唯一內容。

#### Scenario: repo-level 長青事實只存在於 auto-memory

- **WHEN** 某條事實以本 repo 為範圍、跨 change 反覆適用,且僅記載於 auto-memory
- **THEN** 它 SHALL 於 sync/archive 階段被晉升進 `context/` 下性質相符的 concept 檔

#### Scenario: 晉升後回收 memory

- **WHEN** 某份 memory 的內容已全數被 `context/` 涵蓋
- **THEN** 該 memory 檔 SHALL 被刪除
- **AND** `MEMORY.md` 中對應的索引行 SHALL 於同一次操作中一併刪除

#### Scenario: memory 尚有未涵蓋內容

- **WHEN** 某份 memory 僅部分內容被晉升進 `context/`
- **THEN** 該檔 SHALL 保留,SHALL NOT 因部分晉升而整份刪除
- **AND** 已晉升的那部分 SHALL 自該檔移除,以免同一事實存在兩處

#### Scenario: 非 repo-level 的知識不晉升

- **WHEN** 某條 memory 記載的是使用者偏好、跨 repo 的工作習慣,或僅對當次對話有意義的狀態
- **THEN** 它 SHALL 留在 auto-memory,SHALL NOT 進 `context/`
