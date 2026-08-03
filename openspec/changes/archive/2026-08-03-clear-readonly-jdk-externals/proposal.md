## Why

Windows 的 `chezmoi apply` 在 `.local/opt/jdk-17/bin/server/classes.jsa: Access is denied.`
中止。已證實根因是 **DOS `ReadOnly` 檔案屬性**,不是檔案鎖也不是 ACL:

- 失敗當下 Windows 上 java/javaw 程序數為 **0**,推翻「JVM 持鎖」假說。
- 該檔 ACL 為 `FA00571\Howard Wang: FullControl`,權限充足。
- 檔案屬性為 `ReadOnly, Archive`;清掉 `IsReadOnly` 後 `[IO.File]::Open(..., Write)` 立刻成功。

Temurin 的 zip 對少數 entry 帶唯讀權限位,chezmoi 解壓 external archive 時忠實映射成
Windows 的 `ReadOnly` 屬性,下次升版要覆寫**自己寫出來的檔案**時被自己擋住。目前
`jdk-17`、`jdk-21` 各 2 個(`bin/server/classes.jsa`、`classes_nocoops.jsa`),`jdk-8`
另有 15 個(`LICENSE`、`jre/lib/cmm/*.pf` 等)—— jdk-8 下次升版會踩同一個坑。
上游確認 chezmoi 不會為了覆寫而暫時解除唯讀([twpayne/chezmoi#3441](https://github.com/twpayne/chezmoi/issues/3441)),
官方建議的解法就是自己寫 `before_` 腳本;機器上是 v2.72.0(2026-08-02 build),不是版本太舊。

後果不只是「apply 不夠乾淨」。chezmoi 依 **target path 字典序**處理,排在 `.local/` 之後的
所有 target(`.shell_common`、整個 `Documents/`)因此**永遠不會部署,而且無聲** —— apply
輸出只有那一行錯誤,不會說「還有 N 項未處理」。這已造成一次實際故障:
`Documents/_shared-profile.d/26-glab.ps1` 長期停留在待新增,corp GitLab 的 PowerShell
wrapper 在 Windows 上形同不存在,靠跨機比對才發現。

## What Changes

- 新增 Windows-only 的 `run_onchange_before_` 腳本:apply 前清除 `~/.local/opt/jdk-*`
  底下所有檔案的 `ReadOnly` 屬性。腳本模板嵌入五個 JDK 版本 pin,**只有版本一變才重跑**,
  正常 apply 零成本。
- 中止可見化:`chezmoi apply` / `chezmoi update` 非零退出時,明說「字典序在失敗項之後的
  target 都沒有部署」並印出待處理筆數。
  - 不採「每日在 profile 跑 `chezmoi status`」的方案:實測該機 `chezmoi status` 要
    **31 秒**(externals 下 ~2400 檔案要 hash),掛在 shell 啟動路徑上不可接受。
    改成只在失敗後付這個成本。

## Capabilities

### New Capabilities
- `chezmoi-apply-resilience`: apply 期間的抗中止能力 —— external archive 寫出的唯讀檔案
  不得阻塞後續 apply;apply 中止時「後半段 target 靜默落空」必須對使用者可見。

### Modified Capabilities
<!-- 無。既有 spec 的既有需求都不變:externals 定義、JDK 版本切換、腳本慣例照舊。 -->

## Impact

- 新增:`home/run_onchange_before_clear-readonly-externals.ps1.tmpl`
- 修改:`home/Documents/exact__shared-profile.d/` 下的 chezmoi wrapper(pwsh)、
  `home/.chezmoitemplates/shell-common/` 下的對應片段(bash/zsh)
- 不動:`home/.chezmoiexternal.toml`(JDK pin 與 external 型別皆維持原樣)
- 對既有機器的作用:下次 apply 才生效;本機驗證會順帶把 jdk-17 升到 17.0.20+8
