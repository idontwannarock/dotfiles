#!/usr/bin/env bash
# chezmoi modify_ script 本體 — 只管住 herdr config.toml 裡我們確定要的 key。
#
# 為什麼是 modify_ 而不是整檔渲染：herdr 自己會寫這個檔（onboarding 完成後寫
# `onboarding = false`、`herdr config reset-keys` 會重寫 keybindings），整檔渲染
# 會在每次 apply 把它們抹掉。modify_ 拿現有內容進 stdin、吐新內容出 stdout，
# 沒列在下面的 key 一律原樣放行。
#
# herdr 每個 OS 讀不同路徑（`herdr --help` 最後一行會印出實際位置），而 chezmoi 的
# source path 就決定 target path，一份來源檔蓋不了兩個路徑 —— 所以本體放這裡，
# 各 OS 只留一行 wrapper：
#
#   Windows  home/AppData/Roaming/herdr/modify_config.toml.sh.tmpl
#   Linux    home/dot_config/herdr/modify_config.toml.sh.tmpl
#
# 改完要 `herdr server reload-config` 才會套到已在跑的 server；shell 相關的設定
# 還要新開 pane 才生效（既有 pane 是已經 spawn 的行程）。
#
# 未來要「主動砍掉某個 key」時，加一個對稱的 drop()，理由同 .chezmoiremove：
# modify_ 是 patch 不是 render，把 ensure 那行刪掉只代表新機器不會拿到，已經
# 部署出去的機器會永遠留著。要清乾淨就得主動刪，且刪除邏輯要留到每台機器都
# apply 過為止。dot_claude/modify_settings.json.sh.tmpl 的「主動刪除」段是同一件事。

set -euo pipefail

# ensure <table> <key> <value> — filter，stdin 進 stdout 出。
#
# 必須是不動點：拿自己上一輪的輸出再跑一次要逐字節相同，否則每次 apply 都長一行
# （run_after_modify-codex-config.ps1.tmpl 就是踩過這個坑）。做法是「先刪掉該 key
# 在該 table 下的所有出現，再插回 table header 的下一行」—— 位置只由 header 決定，
# 與上一輪的輸出長什麼樣無關。table 不存在才附加到檔尾。
ensure() {
    awk -v tbl="$1" -v key="$2" -v val="$3" '
        function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
        {
            raw[NR] = $0
            t = trim($0)
            if (t ~ /^\[/) { cur = t; hdr[NR] = t }
            owner[NR] = cur
        }
        END {
            want = "[" tbl "]"
            line = key " = " val
            for (i = 1; i <= NR; i++) if (hdr[i] == want) { at = i; break }
            n = 0
            for (i = 1; i <= NR; i++) {
                # 丟掉舊值。hdr[i] == "" 排除 header 自己，只刪該 table 內的 key 行。
                if (owner[i] == want && hdr[i] == "" && trim(raw[i]) ~ "^" key "[ \t]*=") continue
                out[++n] = raw[i]
                if (i == at) out[++n] = line
            }
            if (!at) {
                while (n > 0 && out[n] ~ /^[ \t]*$/) n--
                if (n > 0) out[++n] = ""
                out[++n] = want
                out[++n] = line
            }
            for (i = 1; i <= n; i++) print out[i]
        }
    '
}

# $() 會吃掉尾端換行，最後統一補一個 —— 這也是不動點的一部分。
config="$(cat)"

config="$(printf '%s' "$config" | ensure "ui.sound" "enabled" "false")"
{{- if eq .chezmoi.os "windows" }}

# Windows 沒有 $SHELL，herdr 的 fallback 因此落在系統內建的 powershell.exe（5.1）——
# 那個 shell 不跑 PS7 的 profile，pane 裡 starship 與所有 alias 全部消失。
# 路徑用正斜線：TOML basic string 會把 \ 當跳脫字元。
config="$(printf '%s' "$config" | ensure "terminal" "default_shell" '"{{ lookPath "pwsh" | replace "\\" "/" | default "C:/Program Files/PowerShell/7/pwsh.exe" }}"')"
{{- end }}

printf '%s\n' "$config"
