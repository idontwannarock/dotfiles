## 1. 解除唯讀阻塞

- [x] 1.1 新增 `home/run_onchange_before_clear-readonly-externals.ps1.tmpl`:Windows-only
      閘門、嵌入五個 JDK 版本 pin 作為 onchange hash key、清除 `~/.local/opt/jdk-*` 底下
      所有檔案的 `ReadOnly` 屬性,遵守 repo 的 run_* banner 與段落目的慣例
- [x] 1.2 在 Windows 上先手動執行等效指令清掉 jdk-17 的兩個唯讀檔,確認
      `[IO.File]::Open(..., Write)` 成功
      → 直接跑渲染後的腳本:清掉 jdk-17 (2)、jdk-21 (2)、jdk-8 (15) 共 19 支;重跑報
        `no read-only files`,冪等
- [x] 1.3 `chezmoi apply` 限縮至 `~\.local\opt\jdk-17`,確認 17.0.20+8 升級完成且無
      `Access is denied`;`chezmoi status` 中 jdk-17 的 97 筆歸零
      → `java -version` 回 17.0.20;status 452 → 354,jdk-17 匹配數 0

## 2. 中止可見化

- [x] 2.1 在 `home/.chezmoitemplates/shell-common/base` 加入 `chezmoi` wrapper function
- [x] 2.2 在 `home/Documents/exact__shared-profile.d/96-chezmoi-guard.ps1` 加入等效的
      pwsh wrapper,警告文字與 2.1 一致
- [x] 2.3 驗證:失敗的 apply 印出警告、成功與其他子命令保持安靜
      → bash:`chezmoi apply <not-managed>` 印出警告 + 筆數,rc=1 保留;`chezmoi status` 無雜訊
      → pwsh:Pester 7 則全過(見 3.1)
      → zsh 未單獨跑;wrapper 只用 `local`/`case`/`printf`,與 bash 版同一份 fragment

## 3. 收尾

- [x] 3.1 `tests/chezmoi-guard.Tests.ps1`:mock chezmoi.cmd + 子行程 dot-source,涵蓋
      apply/update 失敗、退出碼保留、global flag 在前、成功路徑與其他子命令的靜默
      → 全套 `Invoke-Pester -Path tests -CI` 16 passed / 0 failed
- [x] 3.2 README `## Troubleshooting` 新增兩節:apply 中止導致字典序在後的 target 靜默
      落空(含判斷方式與防呆位置)、Windows 的 `Access is denied` 根因與自動修復
