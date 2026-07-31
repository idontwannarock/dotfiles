---
type: Reference
title: dotfiles 專案概述
description: "這個 repo 解決什麼問題、承載哪些東西,以及「repo 是 source of truth、不是當前機器上生效的設定」這個核心心智模型。"
---

# 這是什麼

跨平台的**個人** dotfiles 專案,單一使用者、多台機器(Windows / macOS / Linux-WSL),透過 [chezmoi](https://www.chezmoi.io/) 同步。

核心問題:讓一個人的 shell / editor / AI 工具 / toolchain / 開發流程設定,在異質 OS 間可重現、保持同步,並有一條文件化的 fresh-machine bootstrap 路徑。

除了靜態 dotfiles,它還承載:工具安裝與 provisioning 腳本、外部 binary 版本追蹤(Renovate)、一支 Go 寫的 statusline、GitHub Actions,以及一套自家、跨 AI 工具共用的開發流程系統(OpenSpec + discipline skills)。

**最重要的心智模型:這個 repo 是 source of truth,不是當前機器上生效的設定。** 編輯 repo 不會改動當前機器;改動當前機器也不會自動回寫 repo。機器上看到的是 source 被 render 出來的**產物**。
