## 1. 內文

- [x] 1.1 〈定址〉的「接手後第一件事」改成三項清單，第 2 項是驗發問工具
- [x] 1.2 〈派線時關掉線的發問管道〉補「套錯 session」那一格，與既有的「範圍太寬」並列
- [x] 1.3 寫明沒有工具時的處置（請使用者重開，不要繞過）
- 驗證：兩節都能逐條核對；沒有實例可寫時不編軼事

## 2. 驗證

- [x] 2. 四份 wrapper render、無 `<no value>`
- [x] 2. `sh tests/skill-name-map-axis.test.sh` 綠
- [x] 2. 限縮 apply 後 `chezmoi status` 乾淨
- [x] 2. `openspec validate --specs --strict` 全過
- [ ] 2.5 開 PR

## 3. 待查證

- [x] 3.1 `coordinator` 已回覆並以 `ps -eo pid,args` 舉證。**前三次換手永久查不到**（process 已結束，cmdline 隨之消失）——這一格留白未編軼事；改寫進 skill 的是「證據會隨 pane 消失，所以防線要在開線那一刻」
