## 1. 協調者側

- [x] 1.1 `coordinate` 主體新增派線的升級契約要求（旗標與契約必須同時給；D1 的 A/B 實測當證據）
- [x] 1.2 主體寫明範圍只能是 session、三個設定檔層級為何都錯（D2）
- [x] 1.3 主體寫明真人失去 bypass 的代價，以及異議改走文字回報（Risks）
- [x] 1.4 附錄 B 新增旗標的具體寫法，用既有 tool 條件塊區分 Claude／其他 agent（D3、D5）

## 2. 線側

- [x] 2.1 `dev-workflow` 協調模式那節新增第四項義務：無發問管道時具名回報並停下、不要挑預設值
- [x] 2.2 明寫「事後補風險註記不算履行義務」

## 3. 驗證

- [x] 3.1 四個 tmpl 全部 render 不報錯
- [x] 3.2 Codex 版附錄 B 不出現 Claude 專屬旗標；Codex dev-workflow 無裸 skill 名
- [x] 3.3 限縮 apply 至四個 target，`chezmoi status` 乾淨
- [x] 3.4 `openspec validate --strict` 通過
