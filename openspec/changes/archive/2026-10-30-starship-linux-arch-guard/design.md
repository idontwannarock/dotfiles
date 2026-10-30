## Context

`get (dict ...) .chezmoi.arch` 查不到 key 時回傳空字串，模板仍會產生 entry。

## Goals / Non-Goals

**Goals:** 不支援的架構不讓 apply 中斷。

**Non-Goals:** 支援更多架構；把 Windows 與 Linux entry 合併成一張表（會改變 Windows arm64 的行為）。

## Decisions

- 用 `{{- if $starshipArch }}` 包住 entry，而不是 `fail`。`fail` 一樣會讓 apply 中斷，與目標相反。

## Risks / Trade-offs

- [不支援架構的機器上沒有 starship] → shell 的 starship init 本來就以 `command -v` 判斷，沒有 starship 只是沒有 prompt 美化。
