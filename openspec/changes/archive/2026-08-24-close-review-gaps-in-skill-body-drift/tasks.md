## 1. 正確性

- [x] 1.1 `pickup.md:7` 錨點算式補上 `--path-format=absolute` 並置前，與 `handoff.md:20` 同形。
      驗證：該行與 `handoff`／`handoff-list`／`arch-review` 三支逐字比對旗標順序一致。
- [x] 1.2 `review-cross-model.md` Step 4 開頭那句改寫，使它不再宣稱收斂狀態本身即為成功。
      驗證：該句與下方表格對「`done`」的判定一致。
- [x] 1.3 Step 4 表格補上「`idle`/`done` 但無 findings 檔」一列，並在下方寫出分辨流程
      （重送一次 → `agent read` 分類一次 → 依所見選 degrade 理由）。
      驗證：表格四種回報各有出路，且兩個 degrade 理由各有可觀測的觸發條件。
      （blocked by #1.2 —— 同一段落）

## 2. 範圍修正

- [x] 2.1 `grill.md`（L17、L39）兩處 `context/` 帶上 repo root 錨點。
      驗證：`grep -n 'context/' home/.chezmoitemplates/skills/grill.md` 每行可單獨讀出落點。
- [x] 2.2 `arch-review.md`（L21、22、24、76、111、145、146）七處同上。不引入 `openspec/` 詞彙。
      驗證：同上；且該檔仍不提 openspec。
- [x] 2.3 `dev-workflow.md`：刪 L170 贅餘錨點並回復行寬；L161 改寫；內容邊界補回 `docs/` 成四分法。
      驗證：`awk 'length>79'` 對該檔散文段落無輸出；邊界行四格與
      `openspec/specs/project-context/spec.md` 的四分法一致。

## 3. 守衛

- [x] 3.1 新增 `tests/path-format-flag-order.test.sh`：掃 `home/.chezmoitemplates/skills/` 與
      `home/dot_agent/reference/`，對每個 `--git-common-dir` 呼叫點斷言為兩種合法形式之一；
      非呼叫點與反例以行內 `<!-- flag-order: <理由> -->` 豁免。註解 SHALL 寫明它擋形狀不擋語意。
      驗證：`sh tests/path-format-flag-order.test.sh` 綠；`bash` 亦綠。
- [x] 3.2 反向驗證：暫時把 `pickup.md` 改回省略旗標、把某個呼叫點改成置後，測試各須變紅。
      驗證：兩次各自看到 FAIL 行且 exit 非 0；驗完還原。（blocked by #3.1、#1.1）
- [x] 3.3 `.github/workflows/test-shell.yml` 的 `paths:` 補上 `home/.chezmoitemplates/skills/**`
      與 `home/dot_agent/reference/**`。
      驗證：filter 涵蓋 3.1 所掃描的兩個目錄。

## 4. 文字

- [x] 4.1 `repo-identity.md` 新增段落：修掉「in a file this long」、刪 `actually`，
      並帶入具體輸出（root 得 `.git`、子目錄得 `../.git`，皆 exit 0）取代抽象重述。
      驗證：該段與 `coordinate.md:1101-1102` 的對照表說法一致，不相斥。
