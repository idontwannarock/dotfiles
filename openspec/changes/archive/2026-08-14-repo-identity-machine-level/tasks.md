## 1. Machine-level 正典

- [x] 1.1 新增 `home/dot_agent/reference/repo-identity.md`：定義、三步驟各自的理由、兩種捷徑的失敗形狀、使用者清單
- [x] 1.2 `home/dot_agent/reference/index.md` 於 Workflow 分類下列出它
- [x] 1.3 確認純 `.md`、無 template 指令、OKF frontmatter 為固定字面值（符合 `agent-reference-layout`）

## 2. 指路改為絕對路徑

- [x] 2.1 body 2b 改指 `~/.agent/reference/repo-identity.md`
- [x] 2.2 body 2c 的第三份半套算式移除，改為「same canonical slug as 2b」
- [x] 2.3 spec 四處指路（欄位定義、首次開啟 scenario、Active Workflows Index、算式禁令 scenario）全部改為同一個絕對路徑

## 3. principles.md 去算式留推理

- [x] 3.1 移除算式，改為指向正典並說明為何屬 machine-level
- [x] 3.2 補上「指路的目標若本身是 repo-relative，等於沒指」的推論

## 4. 驗收

- [x] 4.1 `dirname(realpath` 在 `context/principles.md` 零命中
- [x] 4.2 body 中 `git rev-parse --git-common-dir` 僅存一處，為 ARCH 偵測，非 slug 推導
- [x] 4.3 spec 四處指路字面一致，皆為 `~/.agent/reference/repo-identity.md`
- [x] 4.4 兩端渲染成功、無未解析 token
- [x] 4.5 `openspec validate --all` 全綠

## 5. 已知未處理（刻意）

- [ ] 5.1 其餘三處確實的複述——`context/glossary.md`、`home/dot_agent/reference/local-files/store.md`、
      `home/.chezmoitemplates/skills/pickup.md`——現在有正典可指，是自然的下一步，但不在本 change 範圍。
