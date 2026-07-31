## Why

三件在上一輪(PR #44)被明確記為範圍外、但已確認存在的問題:

1. **`context/principles.md` 平鋪 25 條,且自我違反。** L21 明文譴責「把當下的檔案樹凍結成需求」,但同一份檔案有三處這種斷言(L15「六個 discipline skills」、L25「6 條 requirement 有 5 條」、L16「Gemini CLI 已放棄,不要去檢查它」——最後這條還是操作指令而非原則)。L21 自己的推論說「修掉一個這類斷言時要把同份文件全掃一遍」,那就該套用在它自己身上。另有三組條目彼此自承同源(L20 說「與上一條是同一個病的兩種症狀」、L27 說「與上一條是不同的軸」、L13 說「與 `run_*` 副作用是同一類陷阱」),卻各自獨立成條。

2. **`docs/renovate.md` 自我矛盾。** L5-7 寫「nothing auto-merges」,L84-87 寫 patch/minor/pin 會 auto-merge。開頭那段寫在 auto-merge 加入之前,沒同步更新。

3. **`docs/superpowers/` 是 155KB 的 pre-OpenSpec 凍結記錄,混在現行文件裡。** 四分法把 `docs/` 定為操作步驟、故障排除與單一案例的理由 —— 凍結的設計與計畫記錄不屬於任何一格,只是因為早於這套分工而留在原地。它內含 6 條失效的相對連結,正是「無人維護的記錄放在有人維護的目錄」的症狀。

## What Changes

- `context/principles.md`:依主題加 `##` 分組小標題;合併三組自承同源的條目;刪除會過期的數量斷言與操作指令;砍贅語。**語意不減是硬約束** —— 每一條原文都要在新版找得到對應。
- `docs/renovate.md`:開頭段落改寫為與 auto-merge 章節一致的敘述。
- `docs/superpowers/` 四份文件搬進 `openspec/changes/archive/`,拆成三個 change 目錄,現有檔案依其實際性質改名為 `design.md` / `tasks.md`。**缺的 artifact 不補** —— 這三個 change 從未有 proposal.md 與 spec delta,編造它們會讓 archive 不再能假設「每一份都是當時真的寫過的東西」。以 `openspec/changes/archive/README.md` 一份說明其出處,不在三個目錄各寫一次。
- `docs/corp-ssh-setup.md` 與 `docs/corp-ssh-setup-windows.md` 指向設計文件的連結改為新路徑。
- `project-context` 的內容邊界補一句:凍結的歷史記錄歸 `openspec/changes/archive/`,不留在 `docs/`。

## Capabilities

### New Capabilities

無。

### Modified Capabilities

- `project-context`: 內容邊界 requirement 補上凍結歷史記錄的歸屬 —— `docs/` SHALL NOT 承載已凍結、不再維護的設計或計畫記錄

## Impact

- `context/principles.md`(25 條,約 4.5KB)
- `docs/renovate.md`(L5-7)
- `docs/superpowers/{plans,specs}/` 四份共 2974 行 → `openspec/changes/archive/` 下三個目錄
- `docs/corp-ssh-setup.md:8`、`docs/corp-ssh-setup-windows.md:8` 的連結路徑
- `openspec/specs/project-context/spec.md`
- OpenSpec CLI 不受影響:`openspec list` 只掃 active change,`openspec validate --all` 只驗 main specs(30 項),archive 對兩者皆為惰性
- 範圍外:`docs/superpowers/plans/` 內嵌草稿段落裡的 6 條失效連結不逐條修 —— 其中一條指向 memory 檔名(`project_wezterm_migration.md`),根本不在 repo 內,無路可修;搬家後它們仍是凍結記錄的一部分
