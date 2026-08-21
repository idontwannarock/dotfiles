## Why

〈派線時關掉線的發問管道〉現在防的是**範圍太寬**（寫進設定檔會把協調者自己一起關掉），
並要求「你必須保留發問能力」。**但它沒防另一種形狀：範圍是對的，套錯 session。**

接班的協調者是**用同一道 `herdr agent start` 指令開出來的**，而那道指令在派線的脈絡下
帶著 `--disallowedTools AskUserQuestion`。照著習慣動作開接班人，**升級鏈就斷在最上面**
——而且**接班人不會知道**：少帶或打錯 tool 名時該旗標只警告、不擋、exit 0，
它只會在第一次需要問人的時候發現自己問不了，而那時它已經在一個沒有出口的狀態裡。

「你必須保留發問能力」這句話**只約束得到現任**。現任讀它的時候，接班人還不存在。

## What Changes

- 〈派線時關掉線的發問管道〉新增一條：**開接班協調者時不得帶那個旗標**，
  且**接手後第一件事要驗自己手上有沒有那個工具**——不能等到需要用的時候才發現。
- 明確區分兩種失效形狀：**範圍太寬**（寫進設定檔）與**套錯 session**（接班人），
  兩者的防法不同，前者靠「不要寫設定檔」，後者靠「交接時驗一次」。
- 〈定址〉那節「接手後第一件事」目前只有「確認名字指著自己，然後廣播」，**補上驗工具**。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `discipline-skills`: `coordinate` 派線契約新增接班協調者的工具驗證要求。

## Impact

- `home/.chezmoitemplates/skills/coordinate.md`
- `openspec/specs/discipline-skills/spec.md`
