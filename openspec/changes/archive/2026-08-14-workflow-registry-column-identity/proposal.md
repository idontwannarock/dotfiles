## Why

`workflow-concurrency` spec 說 registry 的第三欄是 `Project Memory Path`，但 `dev-workflow` 的 body 從頭到尾把它當 active-workflows 路徑用——2b 的讀取清單、ARCH dispatch table、bare-worktree 的手動設定說明，三處都寫「active-workflows path」。

實際資料因此裂成兩半：本機 10 列裡，3 列裝 project memory 路徑、7 列裝 `active_workflows.md` 路徑。欄名沒跟上從 project-memory 改到 active-workflows 的那次搬遷，於是每個寫入者各自解讀。

同一份 spec 也沒說 `Repo` 欄該用什麼形式。`principles.md` 已經釘死 repo 身分只有一個定義——`slug(dirname(realpath(git-common-dir)))`——但 registry 沒引用它，實際出現裸 repo 名、帶前導 `-` 的 slug、不帶前導 `-` 的 slug 三種寫法。後兩者在 `~/.agent/workflows/` 底下裂出成對目錄，其中一個非正典目錄裡躺著一筆正典查詢永遠看不到的 workflow 列。

## What Changes

- `workflow-concurrency` 的 registry 第三欄正名為 `Active Workflows Path`，與 body 既有的說法一致。
- 同一份 requirement 明示 `Repo` 欄 SHALL 為正典 repo slug，並指向 `principles.md` 已有的單一定義。
- 補一則 scenario：非正典 slug 會使同一 repo 的產物落在互相看不見的目錄，屬缺陷而非風格差異。

不做的事：不改 body（body 本來就是對的，這次是讓 spec 追上它）；不動 `Doc Target` 欄的語意；不碰 `active_workflows.md` 本身的格式。

## Capabilities

### New Capabilities

（無）

### Modified Capabilities

- `workflow-concurrency`: registry 第三欄正名並釘住 `Repo` 欄的 slug 形式。

## Impact

- `openspec/specs/workflow-concurrency/spec.md`
- `~/.agent/workflow-registry.md`：per-machine 資料檔，不在版控。本次一併就地遷移（欄名、slug 形式、合併分裂目錄、清除已死列），但該遷移只對這台機器有效，其他機器各自在下次寫入時收斂。
- `home/.chezmoitemplates/skills/dev-workflow.md` 不需修改。
