# TDD

只在預先同意的 seam 上測試。seam 在 grill / design 階段決定,
記錄在 design.md 的 Decisions — 實作中途不新開測試面。

## 循環

- Red before green:先看著測試失敗,才寫實作。
- 垂直切片:一個測試 → 一段實作 → 重複。
  不要橫切(先寫完所有測試再寫完所有實作)。
- 一次一片。前一片綠了才開下一片。
- Refactoring 不在循環內 — 那是 review 階段的事。

## 測試品質

- 好測試讀起來像規格,重構後仍存活。
- 反模式:綁實作細節的測試、恆真測試(靠構造必過)。
- Mock 只放在系統邊界。內部一律走真實介面。
- 細節見 `~/.agent/reference/tdd/tests.md` 與
  `~/.agent/reference/tdd/mocking.md`。

## 邊界

任務無可測 seam、或不值得為它建測試設施時,明說跳過並繼續 —
結果正確性由 {{ .n.verifyDone }} 把關。不硬上。
