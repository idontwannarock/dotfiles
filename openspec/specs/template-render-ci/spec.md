# template-render-ci Specification

## Purpose
規範 `home/` 下所有 chezmoi template 的 render 契約：由 GitHub Actions 在三個 OS 上、於**未經改動的 checkout** 上以 `chezmoi apply --dry-run` 建出完整 target state，template 錯誤即讓 workflow 變紅。此檢查的存在理由是「沒有任何東西在 render 期以外解析 template」——壞掉的 template 會通過所有既有測試、正常合進 main，直到某台機器 `chezmoi apply` 才失敗。

## Requirements

### Requirement: 所有 template 在 PR 階段被 render
`home/` 下的每一個 template SHALL 在針對 `main` 的 pull request 上被 render，render 失敗 SHALL 使 workflow 失敗。

檢查手段 SHALL 是 `chezmoi apply --dry-run`。它建出完整 target state，因此涵蓋 `run_*` 腳本——腳本沒有 target path，`chezmoi cat` 定址不到它們，逐檔迭代的做法會靜默漏掉整個腳本家族。`--dry-run` SHALL NOT 寫入 destination，亦 SHALL NOT 執行任何腳本。

`paths` filter SHALL 涵蓋整個 `home/**`。`.chezmoitemplates/` 下的 fragment 與引用它的 shell 之間沒有路徑關係，因此不存在更窄而仍正確的 filter。

#### Scenario: 共用 body 打錯字
- **WHEN** `.chezmoitemplates/skills/` 下的某個 fragment 引用了不存在的 name-map key，並開 PR
- **THEN** workflow 失敗，錯誤訊息指出 target、source template 與行號

#### Scenario: run_ 腳本 template 壞掉
- **WHEN** 某個 `run_*.tmpl` 的 template 語法錯誤
- **THEN** workflow 失敗——即使該腳本在該 runner 的 OS 上永遠不會執行

### Requirement: 三個 OS 都要跑
Workflow SHALL 在 `ubuntu-latest`、`macos-latest`、`windows-latest` 上各跑一次，且 `fail-fast` SHALL 為 false。

兩處會依平台分歧：`.chezmoiignore.tmpl` 在 Linux 上排除約 31 個 target（`.cmd` shim、Windows-only askpass），其 template 在該 OS 上根本不會被 render；`.chezmoi.toml.tmpl` 自身有 Windows 分支會讀 registry。單一 OS 的綠燈 SHALL NOT 被視為全部 template 都通過。

#### Scenario: 只在 Windows 部署的 template 壞掉
- **WHEN** 某個被 `.chezmoiignore.tmpl` 在 Linux 上排除的 target，其 template 壞掉
- **THEN** ubuntu 那格通過，windows 那格失敗，workflow 整體失敗

#### Scenario: template 自身以 OS 分支
- **WHEN** 某 template 以 `{{ if eq .chezmoi.os "windows" }}` 開頭包住整個 body
- **THEN** 非 Windows 的 runner 完全不會進入該 body（Go template 的 `if` 不求值 false 分支），其中的 `include`、`fail` 與變數引用一律未被驗證；只有 windows 那格才涵蓋它

### Requirement: 先產生 config，再 render
Workflow SHALL 在 render 前執行 `chezmoi init`。

`.chezmoi.toml.tmpl` 提供 `[data]`（`isWSL`、`goMinVersion`、Go tarball pin）。沒有產生過 config 時這些 key 不存在，第一個引用它們的 template 會以與該 PR 無關的理由失敗。`init` 只 render config，不 apply、不執行腳本。

#### Scenario: 略過 init
- **WHEN** 未執行 `chezmoi init` 就 `apply --dry-run`
- **THEN** 於 `.bashrc` 的 `.isWSL` 失敗；此為誤報，SHALL NOT 被當成 template 缺陷

### Requirement: render 的是真實佈局，不得移除任何被引用的檔案
Workflow SHALL 在完整的 checkout 上執行 dry run，SHALL NOT 為了加速或去網路化而刪除、清空或替換 `home/` 下任何檔案。

`--exclude=externals` 只跳過「套用」archive，**不會**阻止 chezmoi 在建 target state 時抓取它們，`--refresh-externals=never` 同樣無效——那些 entry 供應目錄內容。因此本 workflow 每個 OS 會下載約 35 MB、耗時數秒。此成本為刻意接受。

理由來自一次實測失敗：初版刪除 `home/.chezmoiexternal.toml` 以換取 0.2 秒且零網路，Windows 在第一次 CI 就紅——`run_onchange_before_clear-readonly-externals.ps1.tmpl` 以 `include` 讀該檔案，並斷言其中有五個 `$jdkNNVersion` pin。刪掉被別的 template 讀取的檔案，render 出來的是一個不存在的樹；那個版本會是又快又綠，但驗的是錯的佈局。

保留檔案同時使「單獨 render externals」的步驟成為多餘：在 `--exclude=externals` 之下它仍是 target state 的一部分，其 `{{ }}` 錯誤仍會讓本 job 失敗。

#### Scenario: externals 檔案自身的 template 壞掉
- **WHEN** `.chezmoiexternal.toml` 的 `{{ }}` 語法錯誤
- **THEN** workflow 失敗，錯誤指出該檔案與行號

#### Scenario: 提議刪檔加速
- **WHEN** 有人為了去除網路依賴而提議在 render 前移除或清空 `.chezmoiexternal.toml`
- **THEN** SHALL 拒絕；URL 健康度由 `validate-externals.yml` 負責，但**佈局完整性**是本檢查的前提

### Requirement: 失敗時列舉全部，而非只報第一個
Workflow SHALL 在 gate 失敗時額外跑一次逐檔 render，列出每一個失敗的 managed file。

`chezmoi apply` 在第一個 template 錯誤就停止，所以壞了三個 template 的 PR 需要三輪 CI 才找得完。此步驟為診斷用途，SHALL NOT 取代 gate——它以 `chezmoi cat` 逐檔定址，因此涵蓋不到 `run_*` 腳本。

`chezmoi managed` 印出的是相對 destination 的路徑，而 `chezmoi cat` 以 CWD 解析相對引數；診斷步驟 SHALL 以 `$HOME/` 前綴傳入，否則每一檔都回報 "not in destination directory"，真正的失敗會被淹沒。

#### Scenario: 一個 PR 壞了兩個 template
- **WHEN** 兩個不同的 shared body 各有一處錯誤
- **THEN** gate 只報第一個；診斷步驟列出全部受影響的 target，各自標示 source template 與行號
