## JetBrains MCP 搜尋策略

本專案在 JetBrains IDE 中開發，有兩個 MCP Server 可用：
- **JetBrains 官方 MCP Server**（內建）：`get_symbol_info`、`get_file_problems`、`search_in_files_by_text`
- **IDE Index MCP Server**（社群 plugin）：`ide_find_references`、`ide_find_definition`、`ide_call_hierarchy`、`ide_find_implementations`、`ide_find_symbol`、`ide_type_hierarchy`、`ide_find_super_methods`

### 搜尋決策樹

搜尋程式碼時，**優先使用語意搜尋工具**，只在不適用時才 fallback 到 grep/Glob：

```
需要找程式碼？
│
├── 知道確切的 class/method/field 名稱？
│   ├── 想知道它的型別、宣告、文件？
│   │   └── 用 get_symbol_info（官方）
│   ├── 想知道誰引用了它？（Find Usages）
│   │   └── 用 ide_find_references
│   ├── 想知道呼叫鏈？（誰呼叫它 / 它呼叫誰）
│   │   └── 用 ide_call_hierarchy
│   ├── 想跳到宣告位置？
│   │   └── 用 ide_find_definition
│   ├── 是 interface/abstract？想找所有實作？
│   │   └── 用 ide_find_implementations
│   └── 想看繼承鏈？
│       └── 用 ide_type_hierarchy 或 ide_find_super_methods
│
├── 只知道模糊名稱或部分名稱？
│   └── 用 ide_find_symbol（支援模糊匹配和 camelCase）
│       └── 定位到確切符號後，再走上面的路
│
├── 搜尋非程式碼內容？（設定檔、log、文件、README）
│   └── 用 Grep/Glob（文字搜尋）
│
├── 想看檔案有什麼 inspection 問題？
│   └── 用 get_file_problems（官方）
│
└── 以上都不適用，或 MCP Server 不可用？
    └── 用 Grep/Glob 作為 fallback
```

### 使用原則

1. **語意搜尋優先**：在搜尋 Java/Kotlin/Python 程式碼時，永遠先嘗試 MCP 語意工具。它們透過 IDE 的 AST 和索引運作，結果精確且不含噪音（import、註解、同名不同 class 的誤匹配）。
2. **grep 降為 fallback**：只在搜尋非程式碼內容、MCP 工具回傳錯誤、或搜尋目標無法用符號表達時使用 grep。
3. **組合使用**：典型流程是 `ide_find_symbol`（定位符號）→ `ide_find_references`（找引用）→ `ide_call_hierarchy`（追蹤呼叫鏈）。不需要讀取整個檔案來判斷關聯性。
4. **MCP 不可用時**：如果 IDE 處於 indexing 狀態（dumb mode），MCP 工具會回傳 error code `-32001`，此時 fallback 到 grep。可用 `ide_index_status` 預先檢查。
