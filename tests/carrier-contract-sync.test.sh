#!/bin/sh
# carrier-contract-sync.test.sh — 兩份契約的機械判準必須逐字一致。
#
# 線間訊息的升級規則同時寫在兩個地方:`coordinate.md`(協調者讀)與
# `dev-workflow.md` 的線側契約(線讀)。這是**刻意的複寫**,不是疏漏
# ——沒有任何機制會讓實作線載入協調者的 skill,所以規則不寫兩份就送不到線那邊。
#
# 而複寫的代價已經實測過。2026-08-25 觸發字元集移除「括號」時只改了協調者那份,
# 線側仍列著它,於是那次修正**在實際生效的位置上等於沒發生**
# ——因為線讀的是線側那份。只改一份時,**沒被改到的那份正好是唯一會被執行的那份**。
#
# 這支測試比對**值**,不比對措辭。兩份用不同語言寫(中文／英文),
# 比對措辭必然誤報,而一支會誤報的守衛會被關掉。比的是三樣東西:
# 行數門檻、字元數門檻、觸發字元集。
#
# 觸發字元集比的是**存在與否**,不是字面。中文那份寫「反引號」,英文那份寫
# "backtick",指的是同一個字元;所以兩邊各自正規化成同一組記號再比。
# 「括號」也在字彙表裡且**應該兩邊都沒有**——它是上一次漏改的那一項,
# 留在字彙表裡是為了讓它一旦被寫回其中一份就轉紅。
#
# 取值的窗是**緊的**(規則句本身加後面一兩行),不是整段。兩份在規則句之後
# 都有解釋性散文提到括號、提到別的數字;窗一放寬,測試就開始比到散文,
# 那正是「比措辭」的失敗形狀。
#
# 這支測試不檢查什麼:它不檢查兩份的**規則是否正確**,只檢查它們**是否一致**。
# 兩份同時把門檻寫成 3 行,它會綠。
#
# usage: sh tests/carrier-contract-sync.test.sh

set -u

self_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(dirname "$self_dir")

# 母體:兩份契約,各自的錨與窗長。`.github/workflows/test-shell.yml` 的 paths
# 必須涵蓋它們所在的目錄。
coordinator_file='home/.chezmoitemplates/skills/coordinate.md'
coordinator_anchor='只要含反引號'
coordinator_span=2
line_file='home/.chezmoitemplates/skills/dev-workflow.md'
line_anchor='One escalation rule, two triggers'
line_span=3

failures=0

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

finish() {
    if [ "$failures" -eq 0 ]; then
        printf 'ok: the two copies of the escalation rule agree — %s\n' "$sig_coordinator"
        exit 0
    fi
    printf '%d failure(s)\n' "$failures" >&2
    exit 1
}

# 從一份契約抽出它的機械判準,輸出 `lines=<n> chars=<n> triggers=<sig>`。
# 抽不到錨或抽不到兩個數字時輸出空字串,由呼叫端判為失敗
# ——「抽不到」不可以靜默地變成「兩邊都是空的,所以一致」,那是這一族最典型的假綠燈。
extract() {
    ex_path=$1; ex_anchor=$2; ex_span=$3
    awk -v anchor="$ex_anchor" -v span="$ex_span" '
        function carrier_of(t,   c) {
            # 中英各自正規化到同一組記號。兩份用不同語言寫,比字面必然誤報。
            if (index(t, "檔案＋通知格") > 0 || index(t, "file-plus-notice") > 0) return "file+notice"
            if (index(t, "檔案格") > 0 || index(t, "file carrier") > 0) return "file"
            if (index(t, "訊息格") > 0 || index(t, "message carrier") > 0) return "message"
            return ""
        }
        index($0, anchor) > 0 && !seen { seen = 1; left = span }
        seen && left > 0 { buf = buf " " $0; left-- }
        END {
            if (!seen) exit 0
            n = 0
            rest = buf
            while (match(rest, /[0-9]+/)) {
                num[++n] = substr(rest, RSTART, RLENGTH)
                rest = substr(rest, RSTART + RLENGTH)
            }
            if (n < 2) exit 0

            # 觸發字元要**帶界定符**地偵測。裸的 index(buf, "$") 是在兩三行的窗裡
            # 找一個單位元組,而 `$` 與 `!` 在 chezmoi 模板與一般散文裡到處都是
            # ——實測:把 `!` 從規則移除、同時在同一個窗的散文放一個驚嘆號,
            # signature 完全不變,而兩份契約已經真的不一致了。
            sig = ""
            if (index(buf, "反引號") > 0 || index(buf, "backtick") > 0) sig = sig "backtick,"
            if (index(buf, "`$`") > 0) sig = sig "dollar,"
            if (index(buf, "`!`") > 0) sig = sig "bang,"
            if (index(buf, "括號") > 0 || index(buf, "parenthes") > 0) sig = sig "paren,"

            # 規則**指名的載體**也要比。少了這一段,單側把「升為檔案＋通知格」
            # 改成「檔案格」——兩份升級到不同的地方——測試照樣印「一致」。
            cut = index(buf, "升為")
            if (cut == 0) cut = index(buf, "moves to")
            if (cut == 0) exit 0
            from = carrier_of(substr(buf, 1, cut - 1))
            to   = carrier_of(substr(buf, cut))
            if (from == "" || to == "") exit 0

            printf "lines=%s chars=%s triggers=%s from=%s to=%s", num[1], num[2], sig, from, to
        }
    ' "$ex_path"
}

# self-check:在判 repo 之前先判這支測試自己。
#
# 抽取器抽不到東西時回空字串,而**空 == 空**是這一族最危險的假綠燈:
# 兩份都改壞、錨都失效,測試照樣印綠。所以先拿已知的 fixture 餵抽取器,
# 斷言它抽到什麼,而不是斷言下游比對的結果。
self_check() {
    sc_dir=$(mktemp -d) || { fail "無法建立暫存目錄"; return; }
    sc_want='lines=5 chars=500 triggers=backtick,dollar,bang, from=message to=file+notice'

    printf 'x 落在訊息格的內容，只要含反引號、`$`、`!` 任一，或超過 5 行或 500 字元，\n y 一律升為檔案＋通知格。\n' \
        > "$sc_dir/zh.md"
    sc_got=$(extract "$sc_dir/zh.md" '只要含反引號' 2)
    [ "$sc_got" = "$sc_want" ] || fail "self-check:中文側抽取器抽錯了。實得:[$sc_got]"

    printf 'One escalation rule, two triggers. a message carrier moves to the\nfile-plus-notice carrier if it contains a backtick,\n`$` or `!`, or runs past 5 lines or 500 characters.\n' \
        > "$sc_dir/en.md"
    sc_got=$(extract "$sc_dir/en.md" 'One escalation rule, two triggers' 3)
    [ "$sc_got" = "$sc_want" ] || fail "self-check:英文側抽取器抽錯了。實得:[$sc_got]"

    printf 'nothing relevant here\n' > "$sc_dir/miss.md"
    sc_got=$(extract "$sc_dir/miss.md" '只要含反引號' 2)
    [ -z "$sc_got" ] || fail "self-check:錨不存在時應回空字串。實得:[$sc_got]"

    # 裸的驚嘆號不得被當成觸發字元。這是 2026-08-25 實測到的假綠燈。
    printf 'x 落在訊息格的內容，只要含反引號、`$` 任一，或超過 5 行或 500 字元，\n y 一律升為檔案＋通知格。真的別忘了!\n' \
        > "$sc_dir/bare.md"
    sc_got=$(extract "$sc_dir/bare.md" '只要含反引號' 2)
    case "$sc_got" in
        *bang*) fail "self-check:散文裡的裸驚嘆號被當成觸發字元了。實得:[$sc_got]" ;;
    esac

    # 單側改掉目的載體要反映在 signature 上。
    printf 'x 落在訊息格的內容，只要含反引號、`$`、`!` 任一，或超過 5 行或 500 字元，\n y 一律升為檔案格。\n' \
        > "$sc_dir/dest.md"
    sc_got=$(extract "$sc_dir/dest.md" '只要含反引號' 2)
    case "$sc_got" in
        *' to=file') ;;
        *) fail "self-check:單側改掉目的載體時,signature 沒有跟著變。實得:[$sc_got]" ;;
    esac

    # 比對路徑本身也要有斷言,不只驗 extract()。
    [ "$sc_want" = "$sc_want" ] || fail "self-check: 恆等比對失敗"
    [ "lines=6 chars=500 triggers=backtick,dollar,bang, from=message to=file+notice" != "$sc_want" ] || \
        fail "self-check:不同的 signature 被判成相同"

    rm -rf "$sc_dir"
}

self_check
[ "$failures" -eq 0 ] || finish

for f in "$coordinator_file" "$line_file"; do
    [ -f "$repo_root/$f" ] || fail "母體檔案不見了:$f"
done
[ "$failures" -eq 0 ] || finish

sig_coordinator=$(extract "$repo_root/$coordinator_file" "$coordinator_anchor" "$coordinator_span")
sig_line=$(extract "$repo_root/$line_file" "$line_anchor" "$line_span")

# 「抽不到」與「兩邊一致」必須是兩種不同的結果。
[ -n "$sig_coordinator" ] || \
    fail "$coordinator_file 抽不到升級規則(錨:$coordinator_anchor)——規則被改寫過,或錨失效了"
[ -n "$sig_line" ] || \
    fail "$line_file 抽不到升級規則(錨:$line_anchor)——規則被改寫過,或錨失效了"
[ "$failures" -eq 0 ] || finish

if [ "$sig_coordinator" != "$sig_line" ]; then
    fail "兩份契約的機械判準不一致——只改一份時,沒被改到的那份正好是唯一會被執行的那份:"
    printf '  %s\n    %s\n' "$coordinator_file" "$sig_coordinator" >&2
    printf '  %s\n    %s\n' "$line_file" "$sig_line" >&2
fi

# 括號在 2026-08-25 被移出觸發字元集。兩份都不該再有它。
case "$sig_coordinator" in
    *paren*) fail "括號回到了觸發字元集裡。它在雙引號內是字面字元,不觸發任何機制;列入它會讓中文技術散文幾乎每句都升級,等於刪掉訊息格" ;;
esac

finish
