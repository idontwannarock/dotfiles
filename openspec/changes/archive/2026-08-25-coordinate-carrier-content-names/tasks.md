## 1. 位置指涉守衛先紅(TDD)

- [x] 1.1 寫 `tests/carrier-positional-reference.test.sh`,照 `tests/path-format-flag-order.test.sh` 的形狀:宣告母體(`coordinate.md`／`dev-workflow.md`／`openspec/specs/discipline-skills/spec.md`)＋下限、豁免標記帶理由、`self_check()`。禁 `第[①-⑩一二三四五六七八九十]項`／`前後N項`／`第[①-⑩一二三四五六七八九十]格`,**不禁「層」**;跳過表格列與標題行
  - 驗:此刻**必須紅**,且紅的處數 ≈ 40(改名前的母體)。若一開始就綠,測試是空的,重寫
- [x] 1.2 `.github/workflows/test-shell.yml` 的 `paths:` 補 `openspec/specs/**`
  - 驗:`grep -n 'openspec/specs' .github/workflows/test-shell.yml` 有輸出

## 2. 三格改內容命名(讓 1.1 轉綠)

- [x] 2.1 `coordinate.md` 的載體表加一欄印出三個名字;第三列文字由「檔案 ＋ 帶摘要的 prompt」改為「檔案 ＋ 通知」,並把「帶摘要的 prompt」退為說明
  - blocked by 1.1(母體要先有測試守著)
- [x] 2.2 `coordinate.md` body 全部位置指涉改名(~24 行),含 `1242`／`1356`／`1364`／`1373`-`1377`／`1408` 那幾處範圍標記
- [x] 2.3 `dev-workflow.md` 線側契約的 `first kind`／`third kind` 改為 `the message carrier`／`the file-plus-notice carrier`
- [x] 2.4 `openspec/specs/discipline-skills/spec.md` 的 ~12 處改名(與 delta spec 一致)
- [x] 2.5 `context/principles.md:77` 那行改名
  - ⚠️ **不得動 `context/principles.md:51`**(文件四格:`specs/`／`design.md`／`context/`／`docs/`)——同字不同族
  - ⚠️ **不得動 `openspec/changes/archive/` 下任何檔**——歸檔是歷史記錄
- [x] 2.6 逐一列舉驗收:`grep -rn '第[①-⑩一二三四五六七八九十]格' <母體>` 應為 0;`context/principles.md:51` 與 archive 11 檔的差分應為空
  - 驗:`tests/carrier-positional-reference.test.sh` 在 `sh` 與 `bash` 下皆綠
  - blocked by 2.1, 2.2, 2.3, 2.4, 2.5

## 3. 章節交叉引用守衛

- [x] 3.1 寫 `tests/coordinate-section-xref.test.sh`:`coordinate.md` 每個 `〈X〉` 要對到同檔某個 `^#{2,4}` 標題的**子字串**;比對**原始文字**(兩邊都可能帶 `{{ }}` 模板)
  - 豁免(指向 handoff 檔或內文標記,非本檔章節):`Open / unresolved`、`待認領`、`實例甲`、`本輪產生的裁決`、`本輪產生的裁決（不要重新討論）`、`` 動工前重跑 `git fetch` ``、`資源池`
  - 驗:`sh`／`bash` 皆綠;故意把某個 `〈X〉` 改成不存在的名字要轉紅

## 4. 兩份 body 的機械判準同步守衛

- [x] 4.1 寫 `tests/carrier-contract-sync.test.sh`:比對 `coordinate.md` 與 `dev-workflow.md` 的 `5`、`500`、三個觸發字元(`` ` ``／`$`／`!`),**只比值不比措辭**
- [x] 4.2 **實際做一次轉紅實證**:改 `coordinate.md` 那側的 `5` → 跑測試證明轉紅 → 改回 → 再跑證明轉綠。spec 明文規定這類複寫的驗證形式是「先改來源,證明複寫的那一側會紅」,**不得以推理代替**
  - blocked by 4.1

## 5. `117 檔案` 論證改結構性

- [x] 5.1 `coordinate.md` 裡以「117 個檔案、五天」立論的那段,改為「handoff／pickup 工具鏈裡沒有任何東西會刪 `attachments/`(`pickup` 只把 handoff `mv` 進 `archive/`)」
  - 驗:`grep -n '117' home/.chezmoitemplates/skills/coordinate.md` 無輸出

## 6. 收斂

- [x] 6.1 `openspec validate --all` 全過
- [x] 6.2 四支測試(三支新的 ＋ 既有 `path-format-flag-order`)在 `sh` 與 `bash` 下皆綠
  - blocked by 2.6, 3.1, 4.2, 5.1
