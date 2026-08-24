## 1. `dev-workflow.md` 的 `context/` 錨點

- [x] 1.1 將 `home/.chezmoitemplates/skills/dev-workflow.md` 七處裸 `context/`（L87、103、139、159、161、169、172）
      逐處改為帶「repo root 的」錨點；小節標題 `### context/ evergreen promotion` 一併帶錨點。
      驗證：`grep -n 'context/' home/.chezmoitemplates/skills/dev-workflow.md` 每一行都能單獨讀出落點，
      且無任何一行可被讀成 `openspec/context/`。

## 2. `review-cross-model.md` Step 4

- [x] 2.1 Step 4 狀態表新增一列：對造停在自身信任／授權提示但 herdr 回報 `done` → 走 blocked 處置。
      驗證：表格涵蓋 `idle`/`done`/`blocked`/timeout 四種回報，且成功列不再包含「狀態為 done 但實為提示」。
- [x] 2.2 於 Step 4 註明 herdr 回報的是 pane 狀態不是工作狀態，`agent get` 在 agent 已退出後仍回報 `idle`，
      故 findings 檔是唯一證據。驗證：該段與 spec 的兩個新 scenario 一一對應。
      （blocked by #2.1 —— 同一段落）

## 3. `repo-identity.md` 旗標順序

- [x] 3.1 `home/dot_agent/reference/repo-identity.md:17` 錨點算式改為旗標置前，並在旗標說明表補上
      「置後靜默無效且 exit 0」的理由；`realpath` 保留（design D4）。
      驗證：`grep -rn 'git-common-dir --path-format' home/` 無結果。

## 4. 收尾

- [x] 4.1 全 repo grep 複驗沒有別處抄了置後寫法，且 `context/` 在其他 skill body 未出現無錨點用法。
      驗證：兩條 grep 各自的輸出逐條檢視過。（blocked by #1.1、#3.1）
