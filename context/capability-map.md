---
type: Reference
title: 能力面分組
description: "openspec/specs/ 下的 capability 依什麼邊界分組,以及某個新能力該落進哪一組的判準。"
---

# 方位:能力面在哪

完整的能力清單與行為契約在 `openspec/specs/`,每個 capability 一個 `spec.md`。**實際清單以 `openspec spec list` 為準**,此處不複製 —— 逐一列舉會隨 spec 增減而漂移,且那份清單本來就能從檔案系統產生。

這裡給的是清單產不出來的東西:**分組邊界**。每組附判準,新能力依判準歸位;歸位落在既有分組內時,本檔不需修改。

## 分組與判準

**chezmoi 骨架** — 定義 source 樹的形狀、渲染規則,以及 source 檔案本身的撰寫契約:哪些檔案部署到哪、模板如何切分、檔名前綴的語意、`run_*` 腳本該長什麼樣。判準是「這條規則描述 chezmoi 的 source 該怎麼寫、怎麼變成機器上的產物」。

**Provisioning / toolchain** — 在機器上裝東西並維持版本:語言 toolchain、編譯器、CLI 工具、平台專屬的安裝與遷移。判準是「這件事會在使用者機器上產生 chezmoi 未 declare 的副作用」——也因此這組每一項都受「`run_*` 腳本的副作用要顯式反轉」約束。

**外部版本 / 鏡射** — 追蹤與 re-host 外部 binary:釘選版本的自動 bump、上游追不動時的鏡射。判準是「內容的權威在本 repo 之外」。

**自有工具程式** — `tools/` 下的原始碼及其發佈與資料來源:由 CI 編譯成 release,再經 chezmoi external 拉回各平台。判準是「這是我們寫的程式碼,不是設定」。

**CI 驗證關卡** — 在 PR 階段自動執行、失敗即擋下合併的檢查。判準是「這條規則規範的是 CI 要驗什麼、何時觸發」,與上一組的分界是:上一組管**產出**,這組管**把關**。

**開發流程** — 判準是「這條規則規範的是**怎麼做事**,不是機器上有什麼」:流程步驟、紀律、併發與收尾、產出去向。

**知識載體** — 判準是「這規範的是知識放哪、長什麼樣,而非知識本身」。內容本身不在 `specs/`:machine-level 的在 `~/.agent/reference/`,repo-level 的就是你正在讀的 `context/`。

**記憶 / 本機檔案** — 跨 session 的 auto-memory 播種、被 gitignore 的本機檔案備份與還原。判準是「這是刻意不進 git、但要跨 branch/worktree/session 存活的狀態」。

**上手** — fresh machine 從零到可用的文件化路徑。判準是「新機器或新讀者的入口」。

## 讀 spec 時的注意事項

部分 spec 的 `## Purpose` 仍是 archive 時留下的 `TBD` 佔位;它們的真正意圖要看 requirement 內文,別引用佔位行。
