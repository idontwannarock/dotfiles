## 1. 收緊 bootstrap-docs 的 Purpose

- [x] 1.1 將 `openspec/specs/bootstrap-docs/spec.md` 的 Purpose 從「定義 README / docs 的 bootstrap 文件需涵蓋的內容」收緊為只描述入口路徑(README 的 bootstrap 章;`docs/powershell.md` 僅以一致性 rider 出現於單一 requirement),使 Purpose 提到的每個載體在 requirement 裡都有對應斷言
- [x] 1.2 確認 6 條 requirement 一字未動,`openspec validate --all` 通過

## 2. `claude-code.md` + `codex-cli.md`(616 行,8 處確認重複全在此)

每份走完整路徑:逐句套三步規則 → 記台帳 → 改檔 → 驗連結。

- [x] 2.1 逐句掃 `docs/claude-code.md`(515 行),對每一段判定「留 / 刪並指路 / 標 evergreen-candidate」,依據記到 design.md 的台帳附錄(含判「留」者)
- [x] 2.2 依台帳改 `docs/claude-code.md`:移除可一般化的判斷依據,標題下方加一行指向 `context/`;保留組件檔案路徑表、cache 資料流與 `latest.cache` 理由、`jq` 依賴、`CLAUDE_HANDOFF_CONTEXT_WINDOW` 警告、`chat_setting_api` 首跑實例(blocked by 2.1)
- [x] 2.3 逐句掃 `docs/codex-cli.md`(101 行)並記台帳,重點在 34/36/38 三行 —— 36 行自承「不重複記載」卻複述了兩階段掃描與判準來源分層
- [x] 2.4 依台帳改 `docs/codex-cli.md`:36 行只留指路句,刪掉內容摘要(blocked by 2.3)
- [x] 2.5 驗證:`codex-cli.md:36`→`claude-code.md`、`claude-code.md:257`→`rtk.md` 連結可解析;8 處確認重複中屬這兩份的 8 處全數消解,`grep` 確認每個事實只剩一個權威處(blocked by 2.2, 2.4)

## 3. corp-ssh 兩份(678 行)

- [x] 3.1 逐句掃 `docs/corp-ssh-setup.md`(357 行)與 `docs/corp-ssh-setup-windows.md`(321 行)並記台帳。預期多數判「留」—— 這兩份以操作程序為主,且 `principles.md:25`(憑證只留本機)已承載其一般化依據
- [x] 3.2 依台帳改檔;不動 `docs/superpowers/specs/` 的兩份歷史設計文件,也不改指向它們的連結(blocked by 3.1)
- [x] 3.3 驗證兩份間的交叉連結(`corp-ssh-setup-windows.md:10,303,318`、`corp-ssh-setup.md:331`)與 `superpowers/specs/` 連結仍可解析(blocked by 3.2)

## 4. 其餘 10 份(815 行)

- [x] 4.1 逐句掃 `bash.md`、`claude-zai-wrapper.md`、`git-credentials.md`、`powershell.md`、`renovate.md`、`rtk.md`、`ssh.md`、`starship.md`、`user-scripts.md`、`vim.md` 並記台帳
- [x] 4.2 依台帳改檔。已知案例:`powershell.md:32` 的 chicken-and-egg 判「留」(單一案例);`renovate.md` 的人審 gate 敘述若與 `principles.md:29` 同義則刪並指路(blocked by 4.1)
- [x] 4.3 驗證 `claude-zai-wrapper.md:193-195`、`powershell.md:19,39`、`git-credentials.md:14` 的連結與 README 目錄表全數可解析(blocked by 4.2)

## 5. 收尾驗證

- [x] 5.1 台帳完整性:14 份的行數總和覆蓋 2109 行,每份都有判定紀錄,無靜默截斷(blocked by 2, 3, 4)
- [x] 5.2 判準一致性:交叉比對台帳中同類句子的判定,確認三步規則被一致套用;不一致者回頭修正
- [x] 5.3 `openspec validate --all` 通過;`context/` 仍合 `okf-bundle-conventions`(frontmatter 通過 YAML parser、僅 root `index.md` 帶 `okf_version`、相對連結可解析)
- [x] 5.4 全 repo 連結檢查:`docs/` 與 `README.md` 內所有相對 markdown 連結可解析,無因刪段產生的死錨點
