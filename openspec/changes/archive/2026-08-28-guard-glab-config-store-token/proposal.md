## Why

`glab` 有兩條互不相干的憑證來源:

1. **env**(`GITLAB_TOKEN`)—— 本 repo 的 wrapper 走這條,呼叫當下自 vault 取,不落地。
2. **config store**(`~/.config/glab-cli/config.yml`,以及 repo 內的
   `.git/glab-cli/config.yml`)—— **明文** YAML,永久落地。

2026-08-28 在本機 global config store 內發現一顆 53 字元的 corp 權杖明文。實測釐清了
成因:

- `GLAB_CONFIG_DIR=<tmp> GITLAB_TOKEN=dummy-token-abc123 glab api version` 之後,
  該目錄下的 `config.yml` **不含** 該字串 —— glab **不會**把 env 來的權杖寫回
  config store。wrapper 本身是乾淨的。
- 該 host 區段同時帶有 `user:`,而 glab 的自帶註解明說該欄位是「Set automatically on
  login」。寫入者是某次手動執行的 `glab auth login`。

也就是說,破口不在 wrapper 上,而在**繞過 wrapper 的旁路**:`glab auth login` 與
`glab config set token …` 兩條路都直接寫檔,wrapper 完全看不到。既有的
`docs/gitlab-corp-access.md` 已寫明「這套設定刻意不使用 config store」,但那是一句
約定 —— 沒有任何東西在約定被破壞時發出聲音。這次是靠人工翻檔案才發現的,而該權杖
在磁碟上明文躺了多久無從得知。

同一顆權杖此前已外洩兩次;這是第三次,也是第一次由 config store 造成。

## What Changes

- bash/zsh 與 PowerShell 兩份 wrapper 各加一道守衛:呼叫 `glab` 之前檢查 config
  store,發現非空的 `token:` 或 `job_token:` 就**拒絕呼叫**並以 1 結束,訊息同時給出
  清除指令與「該權杖已落地,請輪替」的指示。
- 檢查涵蓋 global 與 repo-local 兩個 store —— 只查其中一個,守衛的宣稱就是假的。
- `docs/gitlab-corp-access.md` 補一節說明這個旁路、守衛的訊息與排除步驟。
- `tests/glab-wrapper.Tests.ps1` 補 regression:有權杖時擋下、無權杖時放行、
  註解行不誤判。

不在範圍內:把權杖從 config store **自動**清掉。守衛只擋不改 —— 悄悄改掉使用者的
憑證檔會讓「權杖曾經落地、必須輪替」這件事消失在無聲之中,而那正是唯一真正重要的
後果。

## Capabilities

### New Capabilities
<!-- 無。 -->

### Modified Capabilities
- `corp-gitlab-access`:憑證來源的約定從「文件寫明不使用 config store」升級為
  「wrapper 在 config store 被寫入時拒絕執行」。

## Impact

- 修改:`home/.chezmoitemplates/shell-common/base`(`glab()`)
- 修改:`home/Documents/exact__shared-profile.d/26-glab.ps1`
- 修改:`docs/gitlab-corp-access.md`
- 修改:`tests/glab-wrapper.Tests.ps1`
- 本機一次性動作(不屬於 repo):已執行 `glab config set token "" --host <corp-host>`
  清除該行;權杖輪替由使用者於 GitLab UI 執行。
