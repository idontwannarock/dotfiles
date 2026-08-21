## Why

PR #111 說「開線那一刻把 argv 落檔」，並在軼事裡寫「當時的分佈是對的」。
**兩件事都不夠準，而不準的方向會讓下一個人以為 `ps` 掃得出這一族。**

1. **argv 裡沒有角色。** `ps` 給的是「有沒有旗標」，要判斷的是「**該不該有**」——
   而機器上還有**第三態**：不屬於任何艦隊的 session（使用者自己開的、別的 repo 的）。
   **它們有沒有旗標都無所謂，而 argv 分不出來。** ⇒ 「分佈全對」這個檢查**本來就答不了**，
   因為第三態讓分母不可知。
2. **附錄 B 的三層命名表**把 herdr 定址名與 `-n` 並列，容易讀成同一層。
   實測：一個 bare `claude`（無 `-n`、無 `--remote-control`）在 herdr 清單裡**仍然有名字**
   ——**定址名來自 `agent rename`，與 `-n` 無關。**

## What Changes

- 〈第二種形狀〉補：**argv 記得了旗標，記不得角色**，所以落檔要**連角色一起落**；
  並把「分佈全對」從一個可驗的結論降級成一個**做不到的檢查**。
- 附錄 B 三層表補一句：**第一層與第二層是各自獨立設定的**，bare `claude` 也會有 herdr 名字。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `discipline-skills`: `coordinate` 接班契約補「落檔要含角色」，並修正三層命名表的獨立性。

## Impact

- `home/.chezmoitemplates/skills/coordinate.md`
- `openspec/specs/discipline-skills/spec.md`
