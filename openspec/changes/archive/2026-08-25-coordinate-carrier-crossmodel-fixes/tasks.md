## 1. 線側對齊(線只載入這一份,所以先修它)

- [x] 1.1 `dev-workflow.md` 觸發字元集**移除 parentheses**(C1),與 coordinate 端及機制表對齊
- [x] 1.2 `dev-workflow.md` 補 **create-only 機制**(C2):存在即中止,不只散文
- [x] 1.3 兩份都**標注「這是複寫、另一半在哪」**——守衛另開,本輪先讓下一個改的人看得見
- [x] 1.4 **線的接班人也要讀 `msgs/`**(C3):改 `coordinate.md` 那句「其餘只有協調者做」,並在 `dev-workflow.md` 的交接自檢加一項
  - 驗:逐字比對兩份的觸發字元集與建檔機制(列舉,不預測)

## 2. 過度宣稱縮回

- [x] 2.1 **`<repo-slug>` 明確選 handoff 派**(C4),寫出理由(搬移目的地是 handoff 的 `attachments/`);**刪掉「與 handoff、workflow 狀態同一個 key」**;引用 `repo-identity.md` 並寫明該處尚未收斂
- [x] 2.2 **`"$(cat file)"` 刪掉假理由**(C5):移除「照樣經過 shell」,保留三個真的;並記下「結論對而理由有一句假」這個形狀
- [x] 2.3 **路徑安全逐元件宣稱**(C6):`<ts>` 定 `YYYYMMDD-HHMMSS`;`<repo-slug>` 由所選派別保證;保留單引號包路徑作為最後一道
  - 驗:`grep` 確認「同一個 key」與「照樣經過 shell」在 body 與 spec 皆已消失

## 3. 覆蓋缺口

- [x] 3.1 **orphan 出口**(C7):通知失敗二選一(換管道重送／降級為第二格),不得放著
- [x] 3.2 **拆艦隊引導句改判準**(C8):從「不屬於任何單線」改為「逐線收尾掃不到的」
- [x] 3.3 **第二格要有長命索引**(C9):只寫檔不留指標等於寫進無索引目錄
  - blocked by 2.1(第二格落點的 slug 要先定)

## 4. 驗證

- [x] 4.1 三支測試 × `sh`/`bash` 全綠
- [x] 4.2 `openspec validate --all` 與 `--changes` 全過
- [x] 4.3 **逐條列舉** 本輪 9 條 scenario 對照 body 實際文字分類
- [x] 4.4 **兩份契約的機械判準逐字 diff**:觸發字元集、長度門檻、建檔機制、檔名形狀——四項各自比對
- [x] 4.5 `chezmoi diff` 逐行歸因後限縮 apply,四個 target 驗空
  - blocked by 1-3
