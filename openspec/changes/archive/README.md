# Archived changes

每個子目錄是一個已完成的 change,保留它當時的 artifact。OpenSpec CLI 不讀這裡 ——
`openspec list` 只回報 active change,`openspec validate --all` 只驗 `openspec/specs/`
下的 main spec。

## pre-OpenSpec 記錄

以下三個目錄早於本專案採用 OpenSpec,原本存放在 `docs/superpowers/`,於 2026-07-31
遷入:

- `2026-04-21-wezterm-migration/`
- `2026-04-24-corp-ssh-redesign/`
- `2026-04-30-corp-ssh-windows-phase2/`

它們**只帶當時真的存在的 artifact**。缺少的 `proposal.md` 與 `specs/` delta 不是
遺失,而是那個年代還沒有這套流程;`.openspec.yaml` 同理省略,因為它們沒有用任何
OpenSpec schema。反推補寫會讓這個目錄不再能假設「每一份都是當時真的寫過的東西」,
而那正是它唯一的價值。

內容維持原樣,未經改寫。因此其中的相對連結有些已失效 —— 它們是相對於舊位置、或
指向本 repo 以外的檔案寫的。失效的連結是記錄的一部分,刻意不修補。

現行的 corp-ssh 操作文件在 `docs/corp-ssh-setup.md` 與 `docs/corp-ssh-setup-windows.md`,
兩者都連向這裡的 design 記錄。
