## Why

前一個 change（`684fb6d`）把 slug 算式的複本換成指路，但指的是 `context/principles.md`——一個 **repo-relative** 路徑。

共用 body 部署到 `~/.claude/skills/` 與 `~/.codex/skills/`，在**每個 repo** 都會跑。在別的 repo 裡那個路徑要嘛不存在，要嘛指到該 repo 自己的 `context/principles.md`（body 本身就把 `context/` 定義為每個專案各有一份的長青 bundle），而那份不會有 repo 身分那一條。

觸發這條指路的分支正是 2b「registry 沒有這個 repo」——最常在別的 repo 發生。結果是：三條禁令、零個做法。這比它取代的半套算式更糟，因為半套算式至少產得出東西。

同一份 body 的 2c 還留著第三份半套算式（「slug derived from `git rev-parse --git-common-dir` as above」），而它的「as above」現在指向一個明文禁止該作法的 2b。前一輪的驗收把 2c 誤判為「非 slug 推導用途」而放行。

## What Changes

- 新增 `home/dot_agent/reference/repo-identity.md`：machine-level 的正典定義，含三個步驟各自的理由、兩種看似正確的捷徑，以及誰在用這把 key。
- `context/principles.md` 保留推理與失敗形狀，算式讓給上述正典；並補上「指路的目標若本身是 repo-relative，等於沒指」這個推論。
- body 的 2b 與 2c、spec 的四處指路，全部改為絕對路徑 `~/.agent/reference/repo-identity.md`。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `workflow-concurrency`: 四處指路的目標改為 machine-level 絕對路徑。
- `agent-reference-layout`: reference tree 新增一個 workflow 類別的葉檔，`index.md` 同步列出。

## Impact

- 新檔 `home/dot_agent/reference/repo-identity.md`（純 `.md`、無 template 指令、OKF frontmatter 為固定字面值）
- `home/dot_agent/reference/index.md`、`context/principles.md`
- `home/.chezmoitemplates/skills/dev-workflow.md`、`openspec/specs/workflow-concurrency/spec.md`
