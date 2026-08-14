## 1. step 2b 補上 Doc Target（Critical #1）

- [x] 1.1 `home/.chezmoitemplates/skills/dev-workflow.md` 的 2b 讀取清單加入 `Doc Target`
- [x] 1.2 同段的新列建立規則明示產出第四欄並留空、此時不得詢問
- [x] 1.3 驗證：team-doc 段落對 2b 的引用（「that step already reads the registry」）現在為真

## 2. body 補上 none 短路與段落順序（Critical #2、Suggestion #3）

- [x] 2.1 team-doc 段落開頭加入 `none` 短路：整段跳過，不問不提案
- [x] 2.2 將能力陳述句 `{{ .n.teamDocGap }}` 上移，擋在「交給 `confluence-team-doc`」之前
- [x] 2.3 「停下」改為停下此步驟並繼續 `finish-branch`，不阻斷流程
- [x] 2.4 驗證：兩端渲染後逐句讀過，確認 Codex 端不再出現「先下指令、後否定可行性」

## 3. 去除重複與壓縮（Simplification #4、#5）

- [x] 3.1 team-doc 段落的內容邊界敘述改為指向 evergreen promotion 段落，不重複三格
- [x] 3.2 two-gates 段落壓縮，逐條對照確認規則（欄位位置、三態、blank≠none、2b 讀取、延後詢問、寫回）皆仍有對應句子

## 4. Spec 調和

- [x] 4.1 `workflow-instructions`：非阻斷性與「停下」界定、`none` no-op 例外單處持有、讀取步驟涵蓋 `Doc Target`、能力陳述先於指令
- [x] 4.2 `workflow-concurrency`：移除「此時不得詢問使用者」——與同檔單向指路矛盾
- [x] 4.3 統一前一輪新增段落的空行風格，與同檔既有段落一致（範圍限本 change 新增處）
- [x] 4.4 `openspec validate --all` 全綠

## 5. 驗收

- [x] 5.1 兩端 `chezmoi execute-template` 渲染成功且 `teamDoc` / `teamDocGap` 仍非空
- [x] 5.2 body 與 spec 逐條對照：spec 的每一條 SHALL 在 body 找得到對應句子，body 沒有 spec 未涵蓋的新規則
