#!/bin/sh
# carrier-positional-reference.test.sh — 序號是位置不是身分。
#
# PR #124 為 `coordinate` 立了三格線間訊息載體,同一輪也立下〈序號不得承重〉:
# 指涉一個分類的成員要用它的**內容命名**,不要用「第五項」這種位置序號,因為
# 插入一項就會讓所有指涉它的文字同時變假,**而且沒有任何東西會轉紅**。
#
# 然後那一輪用「第一格／第二格／第三格」建了約 40 處位置指涉,而那張載體表
# **連編號都沒印**——比收尾清單更不穩定:收尾清單的序號至少印得出來。
# 2026-08-25 使用者裁決改為內容命名(`訊息格` / `檔案格` / `檔案＋通知格`)。
# 這支測試是那次改名的守衛,因為改名本身擋不住下一個人寫回去,而
# 〈取得嚴謹度的方法是守衛,不是告誡〉正面壓在這裡。
#
# 禁止的形狀:`第N項`、`第N格`、`前N項`、`後N項`。
#
# 「層」不在禁止字元集裡,而這是刻意的。〈證據的資格〉的四層與〈送訊息〉的兩層,
# 序號**帶遞進語意**——第①層比第②層更基礎,序號在傳遞資訊而不只是位置。
# 那與收尾清單的純位置不同族。為一個沒有實例的風險擴大禁令,換來的是一份
# 會不斷變長的豁免清單,而長豁免清單本身就是「規則拓寬了」的徵兆。
#
# 沒有「跳過表格列與標題」這種規則,而這是量測的結果不是省略。
# 前一輪的計畫要求跳過它們;但改名完成後整個母體應為 **0 匹配**,
# 所以跳過規則買不到任何東西,只會開一個洞——在表格列裡寫「第三格」就逃掉了。
#
# 母體是下面 scan_roots 宣告的三棵樹。2026-08-25 實測:
# 全部 `第N項`／`第N格` 只出現在 coordinate.md、discipline-skills/spec.md
# 與 context/principles.md,所以豁免只有三條,每條寫明理由。
#
# 下限守的是**檔案數**,不是匹配數。這支測試與 path-format-flag-order 相反:
# 那一支要求呼叫點存在(匹配數有下限),這一支要求匹配為零。
# 匹配數的下限在這裡沒有意義,唯一會靜默失效的是母體本身塌掉
# ——rename、`.chezmoiignore` 改動、半完成的 checkout ——所以下限掛在檔案數。
#
# 豁免是明文的,不是推導的。刻意展示壞形狀的反例必須跳過,而標記要滿足三個條件,
# 每個關掉一個洞:標記只在該行**確實命中**之後才被查詢(所以一行同時有真違規與
# 標記時躲不掉);理由不得為空(空標記等於靜音鈕);且必須在**行尾**
# (否則一份**引用**這個標記的文件會把該行的守衛解除掉——包括這支測試自己印的建議)。
#
#     <!-- positional-ref: <為什麼這一行不是位置指涉> -->
#
# 這支測試不檢查什麼:它是**形狀**檢查。把「第三格」改寫成「那張表的第三列」
# 一樣是位置指涉,一樣會腐爛,而這支測試看不到。沒有機械的真值來源可以判它。
#
# usage: sh tests/carrier-positional-reference.test.sh

set -u

self_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(dirname "$self_dir")

# 母體,寫一次。`.github/workflows/test-shell.yml` 的 paths 必須列出同一批目錄
# ——一支在它的守備對象被改動時不會跑的守衛,等於沒有守衛,而它的沉默
# 在 CI 上與通過長得一模一樣。
# 每棵樹帶一個**檔案數**下限,設在 2026-08-25 實測值之下。
scan_roots='home/.chezmoitemplates/skills:20 openspec/specs:30 context:4'

failures=0
files_seen=0
violations=0
exempt=0

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

finish() {
    if [ "$failures" -eq 0 ]; then
        printf 'ok: 0 positional carrier references across %d files, %d exempt\n' \
            "$files_seen" "$exempt"
        exit 0
    fi
    printf '%d failure(s)\n' "$failures" >&2
    exit 1
}

# 禁止形狀展開成完整字面 token 的 alternation,而不是用 bracket range。
# `[①-⑩]` 這種多位元組 range 在 C locale 下的行為沒有保證,而 CI runner 的
# locale 不在這個 repo 的控制範圍內。逐個列出來是純位元組比對,在哪個 locale
# 下都一樣。
build_pattern() {
    bp_out=''
    for bp_n in 一 二 三 四 五 六 七 八 九 十 ① ② ③ ④ ⑤ ⑥ ⑦ ⑧ ⑨ ⑩; do
        for bp_t in "第${bp_n}項" "第${bp_n}格" "前${bp_n}項" "後${bp_n}項"; do
            if [ -z "$bp_out" ]; then bp_out=$bp_t; else bp_out="$bp_out|$bp_t"; fi
        done
    done
    # 英文側同罪。線側契約(dev-workflow.md)是**英文**寫的,而 spec 自己那條說得很白:
    # 線不載入協調者的 skill,所以只改一份時,**沒被改到的那份正好是唯一會被執行的那份**。
    # 只禁中文 token 等於守了寫規則的人、放過執行規則的人。
    for bp_n in first second third fourth fifth; do
        bp_out="$bp_out|${bp_n} kind"
    done
    printf '%s' "$bp_out"
}
pattern=$(build_pattern)

# 判一行:0 = 乾淨,1 = 位置指涉,2 = 命中但已豁免。
#
# 順序是承重的。先問「有沒有命中」,再問「有沒有豁免標記」——反過來的話,
# 一行同時帶著真違規與一個為別的理由寫的標記時,就整行躲掉了。
judge_line() {
    jl_text=$1
    printf '%s\n' "$jl_text" | grep -qE "$pattern" || return 0
    case "$jl_text" in
        *'<!-- positional-ref: '*' -->'|*'<!-- positional-ref: '*' --> |')
            jl_marker=${jl_text##*<!-- positional-ref: }
            jl_reason=${jl_marker% -->}
            jl_reason=${jl_reason% --> |}
            [ -n "$jl_reason" ] && return 2
            ;;
    esac
    return 1
}

# self-check:在判 repo 之前先判這支測試自己。
#
# 這支測試存在的理由就是 judge_line 分得出那三種情況,而那個判別式壞掉時
# 整份輸出都不可信——包括它印出來的那個「ok: 0 …」。所以拿已知輸入餵它,
# 斷言**它說了什麼**,而不是斷言下游某次執行的顏色。
self_check() {
    sc_fail=0
    while IFS= read -r sc_spec; do
        [ -n "$sc_spec" ] || continue
        sc_want=${sc_spec%% *}
        sc_line=${sc_spec#* }
        judge_line "$sc_line"
        sc_got=$?
        [ "$sc_got" -eq "$sc_want" ] || {
            printf 'FAIL: self-check — 預期判為 %s,實得 %s,輸入:%s\n' \
                "$sc_want" "$sc_got" "$sc_line" >&2
            sc_fail=$((sc_fail + 1))
        }
    done <<'SELFCHECK'
1 跨線事實走第三格（檔案 ＋ 通知）
1 落在第一格的內容一律升級
0 跨線事實走檔案＋通知格（兩個都要）
0 訊息格的內容含反引號就升級
0 這與〈證據的資格〉第②層是同一條規則
0 送訊息：兩層管道，而第二層的規則不能刪
1 不要寫「第五項」——插入一項就會讓所有指涉它的文字同時變假
2 不要寫「第五項」——規則自己舉的反例 <!-- positional-ref: 規則自述，是 mention 不是 use -->
1 不要寫「第五項」 <!-- positional-ref:  -->
1 標記寫成 <!-- positional-ref: 引用它 --> 之後還接著別的字，第三格
2 | 第三格 | 說明 | <!-- positional-ref: 表格列的豁免 --> |
0 這一句完全沒有位置指涉
1 A cross-line fact is always the third kind
1 a message that would otherwise be the first kind
0 a cross-line fact always rides the file-plus-notice carrier
2 "The first kind" is a position <!-- positional-ref: 規則自述 -->
SELFCHECK
    [ "$sc_fail" -eq 0 ] || fail "判別式對已知輸入判錯——下面每一條判定都不可信"
}
self_check
[ "$failures" -eq 0 ] || finish

roots_abs=''
for entry in $scan_roots; do
    root=${entry%:*}
    if [ -d "$repo_root/$root" ]; then
        roots_abs="$roots_abs $repo_root/$root"
    else
        fail "母體目錄不見了:$root"
    fi
done
[ "$failures" -eq 0 ] || finish

# stderr 被接住,不是被丟掉:「讀不到」不可以變成「裡面沒問題」。
err_file=$(mktemp) || { fail "無法建立暫存檔"; finish; }

# shellcheck disable=SC2086
matches=$(find $roots_abs -type f \( -name '*.md' -o -name '*.md.tmpl' \) \
    -exec grep -nE "$pattern" /dev/null {} + 2>"$err_file")
grep_status=$?

if [ -s "$err_file" ]; then
    fail "掃描寫了東西到 stderr——掃描不完整,它的判定就沒有意義:"
    sed 's/^/  /' "$err_file" >&2
fi
[ "$grep_status" -le 1 ] || fail "grep 以 $grep_status 結束——掃描不完整"
rm -f "$err_file"

for entry in $scan_roots; do
    root=${entry%:*}
    floor=${entry##*:}
    count_err=$(mktemp) || { fail "無法建立暫存檔"; finish; }
    found=$(find "$repo_root/$root" -type f \( -name '*.md' -o -name '*.md.tmpl' \) \
        2>"$count_err" | wc -l)
    found=$((found))
    if [ -s "$count_err" ]; then
        fail "$root 的檔案清點寫了東西到 stderr:"
        sed 's/^/  /' "$count_err" >&2
    fi
    rm -f "$count_err"
    files_seen=$((files_seen + found))
    [ "$found" -ge "$floor" ] || \
        fail "$root 底下只掃到 $found 個檔(下限 $floor)——母體縮水了"
done

while IFS= read -r record; do
    [ -n "$record" ] || continue
    file=${record%%:*}
    rest=${record#*:}
    lineno=${rest%%:*}
    text=${rest#*:}
    rel=${file#"$repo_root"/}

    judge_line "$text"
    case $? in
        0) continue ;;
        2) exempt=$((exempt + 1)); continue ;;
    esac

    violations=$((violations + 1))
    fail "$rel:$lineno 以位置序號指涉一個分類的成員:"
    printf '  %s\n' "$text" >&2
    printf '  改成內容命名（載體是 訊息格／檔案格／檔案＋通知格），或者——\n' >&2
    printf '  如果這一行是刻意的反例,在行尾加一個帶理由的 positional-ref 標記。\n' >&2
done <<EOF
$matches
EOF

finish
