## ADDED Requirements

### Requirement: 含非 ASCII 的 profile 片段 SHALL 帶 UTF-8 BOM

`Documents/_shared-profile.d/` 底下含非 ASCII 的 `.ps1` SHALL 以 UTF-8 BOM(`EF BB BF`)開頭。

這些片段同時被 PS 5.1 與 PS 7 的 profile loader dot-source,而 PS 5.1 的 parser 對無 BOM 檔案退回系統 ANSI codepage,中文序列 mojibake 後可能吃掉引號,並在無關的行報出 parser 錯誤。

#### Scenario: 片段的前三個位元組

- **WHEN** 檢查 `Documents/_shared-profile.d/` 下任一含非 ASCII 的 `.ps1`
- **THEN** 檔案前三個位元組為 `EF BB BF`
