---
okf_version: "0.2"
---

# Project Context

給「做需求分析」時進入狀況用的長青背景文件。model-agnostic、人可讀,**不自動載入** —— 需要時由 `grill`、`arch-review` 等主動讀取。

**範圍邊界**:這裡放專案的*為什麼存在、怎麼想這個 domain、有哪些反覆適用的原則*。「系統現在做什麼(WHAT、可驗收)」在 `openspec/specs/`;「某次 change 當下的方案選擇」在該 change 的 `design.md`。三者不重疊。

## 何時讀哪一份

* [專案概述](overview.md) - 這個 repo 解決什麼問題、承載哪些東西,以及最重要的心智模型(repo 是 source of truth,不是當前機器上生效的設定)。**第一次接觸本專案先讀這份。**
* [詞彙表](glossary.md) - chezmoi 模型、Git 工作區、開發流程、跨工具部署、承載物與自動化五組 domain 術語。遇到不認識的名詞、或需要權威的模組邊界判準時查這份。
* [反覆適用的原則與約束](principles.md) - 跨 change 反覆適用的長青判斷依據。**動手改任何東西前讀這份**,多數「為什麼不能這樣做」的答案在這裡。
* [能力面分組](capability-map.md) - `openspec/specs/` 下的 capability 依什麼邊界分組。要找某個行為契約在哪、或新能力該歸哪一組時讀這份。
