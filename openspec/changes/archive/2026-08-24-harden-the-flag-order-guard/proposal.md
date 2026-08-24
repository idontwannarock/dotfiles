## Why

上一輪新增的 `tests/path-format-flag-order.test.sh` 通過了它自己的反向驗證，卻在對抗式 review 下
被複現出四種「印 ok 且 exit 0，而違反確實存在」的路徑。其中最尖銳的一條：豁免標記在
`rev-parse` 閘門**之前**檢查且不要求理由，於是**任何引用該標記的文件都會自我豁免**——而守衛
失敗時印出的訊息，正是叫讀者貼上那串字。

守衛的判定又是**整行**子字串比對：同一行兩個呼叫只看第一個、屬於別的指令的
`--path-format` 被算進來、同一列表格另一格的 `basename "$(git…)"` 赦免整列。這三種在本 repo
的文件裡都不是假想——`coordinate.md:1101-1103` 就是一張每列多個指令的表。

一支能被自己的錯誤訊息解除武裝的守衛，比沒有守衛更糟：它會讓「我檢查過了」這句話重新
變成不可反駁的。

**兩條被推翻的指控一併記錄**（它們是這輪唯二未採納的 review 結論）：`post-checkout:14` 不是
bug——實測 git 跑 hook 時 cwd 一律是工作樹頂層，該處 `--git-common-dir` 回 `.git` 且展開正確，
而所有 worktree 情境下它本來就回絕對路徑；`operating.md:26` 的 `.../.bare` 也成立——實建一個
bare+worktree 佈局測得無旗標同樣回絕對路徑。兩條指控都是**在錯的佈局裡測**得出的。

## What Changes

**守衛的判定精度**

- 判定窗口由「整行」縮到**每一個 invocation**：對行內每個 `--git-common-dir` 出現處，
  只往前取到最近的 `rev-parse` 為止，在該窗口內判形式。
- 走完行內**所有**出現處，不再只看第一個。
- 豁免標記移到 `rev-parse` 閘門**之後**檢查，要求非空理由與收尾 `-->`，並錨定於行尾——
  句中引用的範例不再解除武裝。

**守衛的母體完整性**

- 不再以 `2>/dev/null` 吞掉 `find`／`grep` 的錯誤：stderr 有內容即失敗，並檢查 grep 的
  exit code（0／1 正常，>1 為錯誤）。
- 母體下限由 `call_sites > 0` 改為**每個掃描根各有下限**，並斷言掃到的檔案數。
- `-name` 涵蓋 `*.md.tmpl`（chezmoi 自己的副檔名，一次 `chezmoi add --template` 之遙）。
- 掃描根抽成單一變數，讓「掃描根與 CI filter 必須一起動」由結構保證而非由註解提醒。

**守衛的自述必須為真**

- 修正標頭裡自相矛盾的驗屍報告（「五支抄它的都正確」與「`pickup.md` 整個省略」不能並存；
  後者才是事實）。
- 修正「七個 form (b) 呼叫點」——範圍內實為**四個**；那三支腳本是**第三種安全形式**
  （原始捕捉 ＋ 呼叫者控制的 cwd），且**不在掃描母體內**。
- 〈WHAT THIS DOES NOT CHECK〉SHALL 明寫可執行程式不在母體內，並說明為何不納入
  （它們的正規化發生在後續行，同行判定必誤報）。

**文件**

- `review-cross-model.md` Step 5 的「confirm as in Step 4」限定其承接範圍，並釘死該情境的
  退化理由為 `rebuttal exchange incomplete`。
- `coordinate.md:1101` 的標記移進最後一格，不再多出第四格。
- 掃描根缺失時的提早 exit 走與其他路徑相同的總結輸出。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `session-handoff`: 「一致性由測試強制」補上母體與判定精度的要求——判定 SHALL 以 invocation
  為單位、豁免 SHALL 要求非空理由、母體縮減 SHALL 使測試失敗、且測試 SHALL 明述其母體邊界。
- `cross-model-review`: Step 5 承接 Step 4 的範圍 SHALL 明確，一個情境 SHALL 只對應一個退化理由。

## Impact

- `tests/path-format-flag-order.test.sh`（大幅改寫）
- `home/.chezmoitemplates/skills/review-cross-model.md`、`coordinate.md`
- spec delta：`session-handoff`、`cross-model-review`
- 三支可執行腳本**不動**——已實測安全，且本輪明確把它們寫在母體之外
