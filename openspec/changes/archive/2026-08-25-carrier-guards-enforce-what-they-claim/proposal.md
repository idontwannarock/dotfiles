## Why

上一輪(PR 分支 `feat/coordinate-carrier-content-names`)加的三支守衛,**不守它們宣稱要守的東西**。
六個同家族 lens 以變異測試、cross-model counterpart 以獨立蒐證,雙方各自命中同一族缺陷:

- 豁免標記讓**整行**免疫,而檔頭明文宣稱這個 case 抓得到
- 同步守衛的 `$`／`!` 是在整個窗裡找單一位元組,單側漂移可以被一句散文掩蓋
- 同步守衛的 signature 不含規則指名的載體,單側改名照樣印「一致」
- 位置指涉守衛的回報路徑在健康 repo 上從不執行,把違規改判成豁免仍全綠

**看起來在守、其實沒守的測試比沒有測試更危險**——它讓人停止再看。

## What Changes

- **豁免標記綁 token**:標記要指名它豁免的是哪一個 token,該行其餘命中一律照舊轉紅。理由拒收純空白;行尾判定容忍尾隨空白,並拒絕標記後另有 HTML 註解。
- **字元集補齊**:Arabic 數字、超過十、大小寫不敏感,英文側補 `carrier`／`slot`(線側契約用的正是 "carrier",而 `kind` 在該檔另有 agent kind 的意思)。
- **同步守衛只探帶反引號的 token**,並把**規則指名的來源／目的載體**納入 signature。
- **位置指涉守衛補 fixture 層**(`message_check`),斷言它說了什麼——含「豁免的那行不得被點名」。
- **xref 豁免改以 `檔案 + 名字` 為鍵**,不再全域比對。
- **`spec.md` 兩條互相衝突的 SHALL 收束**(第三列該寫什麼)。
- **CI 真的用 bash 跑一遍**:現行 harness 永遠是 `sh`,兩支新測試不讀 `SEED_SH`,所以 job log 上那兩行綠是同一次執行。
- 移除永不觸發的 `grep_status` 檢查;修正四處與現實不符的敘述與計數。

## Capabilities

### New Capabilities

(無)

### Modified Capabilities

- `discipline-skills`: 豁免 SHALL 綁 token 而非整行;同步守衛 SHALL 涵蓋規則指名的載體;
  守衛 SHALL 有一層斷言自己輸出的 fixture 檢查;交叉引用豁免 SHALL 以出現位置為鍵。

## Impact

- `tests/carrier-positional-reference.test.sh`、`tests/coordinate-section-xref.test.sh`、`tests/carrier-contract-sync.test.sh`
- 樹裡既有的 6 個 `positional-ref` 標記(格式改變,全部要改寫)
- `.github/workflows/test-shell.yml` —— 註解修正 ＋ 真正的 bash 執行
- `openspec/specs/discipline-skills/spec.md:443`、`home/.chezmoitemplates/skills/coordinate.md:787`、`dev-workflow.md`
