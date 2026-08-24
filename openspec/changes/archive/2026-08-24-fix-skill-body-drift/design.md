## Context

三項都源自 #118 那一輪的實測，不是紙上推演：

- **`context/` 錨點**：`dev-workflow.md` 的七處 `context/` 全部沒有錨點，而該檔通篇在講 `openspec/`
  底下的 artifact 流程。相對路徑在一個滿是 `openspec/` 的文脈裡，最近的錨點就是 `openspec/`。
  已在 `mms_product_grouping_api` 造成實際漂移（該 repo 現在真的有 `openspec/context/`）。
- **Step 4 狀態表**：本輪各實測到一次——(a) 對造 CLI 停在自己的信任／授權提示，herdr 回報 `done`；
  (b) 對造 agent 已退出，`agent get` 仍回報 `idle`。兩者都落在現行表的成功列。
- **旗標順序**：`repo-identity.md:17` 寫成置後。實測置後靜默無效且 exit 0。諷刺的是抄它的五支 skill
  body 全都寫對了——錯的是正典，對的是副本。

## Goals / Non-Goals

**Goals:**

- 三處敘述改成「照字面執行也不會錯」，而不只是「懂的人讀得懂」。
- 把兩項實測到的失敗模式寫進 spec，讓它們在下次被人重新推導掉時有東西可比對。

**Non-Goals:**

- 不改 `openspec/specs/project-context/spec.md`——它已明寫 repo root。
- 不處理 `mms_product_grouping_api` 那一端（跨 repo，依規則另開 handoff）。
- 不動導航索引／MAP 拓撲那條線（另一輪大的）。

## Decisions

**D1：`context/` 的錨點寫成散在各處的行內修飾，不集中成一句定義。**
另一個選項是在檔頭寫一次「本檔所有 `context/` 均指 repo root」，正文保持乾淨。否決理由：讀者是逐段跳讀
skill body 的 agent，不是從頭讀到尾的人。一句在檔頭的定義，對第 169 行才被載入視野的那一段不生效——
而這正是漂移發生的方式。行內修飾冗贅，但冗贅是這裡的功能。

**D2：Step 4 的兩件事掛進既有 requirement，不另立新條。**
`cross-model-review` 已有「收斂狀態不等於 prompt 已送達」。授權提示被算成 `done`、退出後仍回報 `idle`，
與它同一個根因：**herdr 的狀態是 pane 的狀態，不是工作的狀態**。散成三條 requirement 會讓下次讀的人
三次各自推導；掛在一起，根因只講一次。

**D3：旗標順序寫進 `session-handoff` spec，而不只是修 body。**
`discipline-skills:589` 已有這條，但它長在 coordinate 的 cwd 守衛脈絡下。handoff 家族的 slug 算式是
另一個獨立的使用點，而它的正典（`repo-identity.md`）就是這次寫錯的那份。只修 body 而不動 spec，等於
把「為什麼順序有關」再次留在沒人找得到的地方。

**D4：`realpath` 保留，不因旗標修好而拿掉。**
兩者防的不是同一件事：旗標決定 git 印絕對還是相對，`realpath` 解 symlink 與 `..`。現在 `realpath` 順手
蓋住了旗標的錯，但那是巧合不是設計；把它當成 fallback 移除，會讓下次旗標寫錯時直接爆在使用端。

## Risks / Trade-offs

- **七處行內修飾讓 `dev-workflow.md` 變囉唆** → 接受。D1 的理由就是這個囉唆有功能；且修飾詞短
  （「repo root 的 `context/`」），不改變段落結構。
- **`session-handoff` 與 `discipline-skills` 現在有兩條講同一件事的旗標順序規則** → 接受並顯性化：
  兩者是不同能力的不同使用點，不是重複。若日後合併，該合的是「路徑錨點算式」這個共用概念，
  屬 MAP 拓撲那一輪的範圍。
- **Step 4 新增的兩個 case 各只實測到一次** → 標明是實測而非推論，並在 scenario 裡寫下觀察到的
  kind 條件，讓下次遇到不同結果的人知道要比對什麼。

## Migration Plan

無。三個檔皆為文件／指令敘述，非 `modify_`／`run_` 腳本，`chezmoi apply` 只是覆寫檔案內容。
回退即 revert commit。

## Open Questions

無。
