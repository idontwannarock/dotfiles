#!/bin/sh
# coordinate-section-xref.test.sh — 〈X〉 要指得到一個真的章節。
#
# `coordinate.md` 用〈X〉這個標記交叉引用自己的章節,而它有 33 個引用、56 個標題,
# 全部靠人腦維持一致。改一個標題的措辭,指向它的每一處引用同時變成死連結
# ——**而且沒有任何東西會轉紅**。這是〈序號不得承重〉的同族失敗:
# 指涉的目標改了名,指涉本身不會知道。
#
# 比對是**子字串**,不是等值。這是刻意的,不是寬鬆:
# 〈複寫了別處的事實〉合法地指向「## 認得「複寫了別處的事實」這一族」
# ——引用取的是那一族的名字,標題多帶了分類語。要求等值會讓這種正確用法全部轉紅,
# 而一支在第一次跑就誤報的守衛會被關掉,留下比沒有守衛更糟的東西:一盞沒人看的紅燈。
#
# 比對的是**原始文字**,不是渲染後的文字。〈與 {{ .n.devWorkflow }} 的關係〉
# 這種引用兩邊都帶著模板;先渲染再比對會引入一個「用哪組變數渲染」的問題,
# 而那個問題沒有唯一答案(同一份 body 有兩個 tool 分支)。原始文字有。
#
# 豁免是明文的,不是推導的。下面七條指向的不是本檔章節而是 handoff 檔的段落
# 或內文標記,每條寫明指向何處。它們用一張表宣告,不是用啟發式規則
# ——啟發式(「跳過 code fence」「跳過表格」)會在措辭被改寫時自己重新判一次,
# 而措辭被改寫正是這種漂移發生的時候。
#
# 這支測試不檢查什麼:它檢查引用**解析得到**,不檢查它指對了地方。
# 〈A〉指向一個確實存在但語意上不相干的〈A 的反例〉,這支測試會綠。
# 沒有機械的真值來源可以判那個。
#
# 抽取用 index()／substr(),不用正規表示式,也不用寫死的位元組偏移量。
# `[^〉]*` 這種否定字元集在 C locale 下是「排除〉那三個位元組」,遇到任何 CJK 字
# 就提早停——整支測試會靜默漏抓,印出綠燈。而 index() 與 substr() 在同一次執行裡
# 用同一種模式(字元或位元組),所以**彼此一致**,兩種 locale 下都對。
# 標題比對也避開 `{2,4}` 這種 interval:CI 的 ubuntu-latest 預設 awk 是 mawk。
#
# usage: sh tests/coordinate-section-xref.test.sh

set -u

self_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(dirname "$self_dir")

# 母體。`.github/workflows/test-shell.yml` 的 paths 必須涵蓋同一批目錄。
scan_root='home/.chezmoitemplates/skills'
# 下限:掃到的檔案數,與抽出的引用數。引用數的下限守的是「抽取本身壞掉」
# ——正規表示式失手時結果是 0 個引用、0 個失敗,那會印出一個漂亮的綠燈。
floor_files=20
floor_refs=28

# fixture 模式:message_check 用它把整支腳本跑在一個丟棄式目錄上。
if [ -n "${XREF_FIXTURE_DIR:-}" ]; then
    repo_root=$(dirname "$XREF_FIXTURE_DIR")
    scan_root=$(basename "$XREF_FIXTURE_DIR")
    floor_files=0
    floor_refs=0
fi

failures=0
refs_seen=0
files_seen=0
exempt=0

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

finish() {
    if [ "$failures" -eq 0 ]; then
        printf 'ok: %d section references resolve across %d files, %d exempt\n' \
            "$refs_seen" "$files_seen" "$exempt"
        exit 0
    fi
    printf '%d failure(s)\n' "$failures" >&2
    exit 1
}

# 豁免表:一行一條,`<引用名>\t<理由>`。理由不得為空。
# fixture 模式下清空,否則 fixture 的判定會被真實豁免污染。
exemptions=$(
    [ -n "${XREF_FIXTURE_DIR:-}" ] && exit 0
    cat <<'EXEMPT'
Open / unresolved	指向 handoff 檔的段落標題,不是本檔章節
待認領	指向 handoff 檔的段落標題,不是本檔章節
實例甲	內文標記(一則軼事的代號),不是章節
本輪產生的裁決	指向 handoff 檔的段落標題,不是本檔章節
本輪產生的裁決（不要重新討論）	指向 handoff 檔的段落標題,不是本檔章節
動工前重跑 `git fetch`	指向收尾清單裡的一項,不是章節
資源池	指向名冊表的一個欄位,不是章節
EXEMPT
)

# 迴圈跑在 subshell 裡,所以用**離開碼**回話——而 `while` 正常跑完也是 0,
# 於是「找到了」與「找完了都沒找到」在管線的離開碼上長得一模一樣。
# 所以迴圈之後要明確 `exit 1`。少了那一行,空的豁免表會把每一條引用都判成豁免,
# 印出一盞漂亮的綠燈;self-check 就是這樣抓到它的。
is_exempt() {
    ie_name=$1
    printf '%s\n' "$exemptions" | {
        while IFS='	' read -r ie_ref ie_reason; do
            [ -n "$ie_ref" ] || continue
            [ "$ie_ref" = "$ie_name" ] || continue
            # 理由為空的豁免等於靜音鈕,不算數。
            [ -n "$ie_reason" ] && exit 0
        done
        exit 1
    }
}

# 抽出引用與標題,並判每個引用解析得到沒有。
# awk 把整檔讀進陣列再處理:檔案都是幾千行的 markdown,不值得為串流最佳化,
# 而兩趟讀同一個檔在 POSIX awk 裡沒有乾淨的寫法。
scan_prog='
    { line[FILENAME, ++n[FILENAME]] = $0 }
    END {
        ob = "〈"; cb = "〉"
        for (f in n) {
            hc = 0
            for (i = 1; i <= n[f]; i++) {
                L = line[f, i]
                if (L ~ /^## / || L ~ /^### / || L ~ /^#### /) heads[++hc] = L
            }
            for (i = 1; i <= n[f]; i++) {
                rest = line[f, i]
                while ((a = index(rest, ob)) > 0) {
                    rest = substr(rest, a + length(ob))
                    b = index(rest, cb)
                    if (b == 0) break
                    name = substr(rest, 1, b - 1)
                    rest = substr(rest, b + length(cb))
                    if (name == "") continue
                    ok = 0
                    for (h = 1; h <= hc; h++)
                        if (index(heads[h], name) > 0) { ok = 1; break }
                    printf "%s\t%d\t%s\t%s\n", f, i, (ok ? "ok" : "unresolved"), name
                }
            }
        }
    }
'

# self-check:在判 repo 之前先判這支測試自己。
#
# 這支測試存在的理由是它分得出「解析得到」與「解析不到」,而那個判別式壞掉時
# 它會印出一個漂亮的綠燈。所以先拿已知輸入跑整支腳本,**斷言它說了什麼**,
# 不是斷言它的顏色——顏色對而訊息錯的守衛在這個 repo 已經有過實測敗績。
message_check() {
    mc_dir=$(mktemp -d) || { fail "無法建立暫存目錄"; return; }
    {
        printf '## 認得「複寫了別處的事實」這一族\n'
        printf '見〈複寫了別處的事實〉,這是子字串比對要放行的形狀。\n'
        printf '## 與 {{ .n.devWorkflow }} 的關係\n'
        printf '見〈與 {{ .n.devWorkflow }} 的關係〉,兩邊都帶模板,比對原始文字。\n'
        printf '見〈這個章節不存在〉,應該要紅。\n'
    } > "$mc_dir/fixture.md"

    mc_out=$(XREF_FIXTURE_DIR="$mc_dir" "$SHELL_UNDER_TEST" "$0" 2>&1)
    rm -rf "$mc_dir"

    case "$mc_out" in
        *'這個章節不存在'*) ;;
        *) fail "self-check:解析不到的引用沒有被報出來。實得:"
           printf '%s\n' "$mc_out" | sed 's/^/  /' >&2 ;;
    esac
    case "$mc_out" in
        *'複寫了別處的事實'*)
           fail "self-check:子字串比對誤報了一個合法引用。實得:"
           printf '%s\n' "$mc_out" | sed 's/^/  /' >&2 ;;
    esac
    case "$mc_out" in
        *'devWorkflow'*)
           fail "self-check:帶模板的引用被誤報——比對應針對原始文字。實得:"
           printf '%s\n' "$mc_out" | sed 's/^/  /' >&2 ;;
    esac
}
if [ -z "${XREF_FIXTURE_DIR:-}" ]; then
    SHELL_UNDER_TEST=${SEED_SH:-sh}
    message_check
    [ "$failures" -eq 0 ] || finish
fi

root_abs="$repo_root/$scan_root"
[ -d "$root_abs" ] || { fail "母體目錄不見了:$scan_root"; finish; }

err_file=$(mktemp) || { fail "無法建立暫存檔"; finish; }
records=$(find "$root_abs" -type f \( -name '*.md' -o -name '*.md.tmpl' \) \
    -exec awk "$scan_prog" {} + 2>"$err_file")
scan_status=$?
if [ -s "$err_file" ]; then
    fail "掃描寫了東西到 stderr——掃描不完整,它的判定就沒有意義:"
    sed 's/^/  /' "$err_file" >&2
fi
[ "$scan_status" -eq 0 ] || fail "awk 以 $scan_status 結束——掃描不完整"
rm -f "$err_file"

files_seen=$(find "$root_abs" -type f \( -name '*.md' -o -name '*.md.tmpl' \) | wc -l)
files_seen=$((files_seen))
[ "$files_seen" -ge "$floor_files" ] || \
    fail "只掃到 $files_seen 個檔(下限 $floor_files)——母體縮水了"

while IFS='	' read -r file lineno status name; do
    [ -n "${name:-}" ] || continue
    refs_seen=$((refs_seen + 1))
    [ "$status" = "unresolved" ] || continue
    rel=${file#"$repo_root"/}
    if is_exempt "$name"; then
        exempt=$((exempt + 1))
        continue
    fi
    fail "$rel:$lineno 的〈$name〉對不到本檔任何標題:"
    printf '  改成某個真實標題的子字串，或者——\n' >&2
    printf '  如果它指的不是本檔章節,把它加進這支測試的豁免表並寫明指向何處。\n' >&2
done <<EOF
$records
EOF

[ "$refs_seen" -ge "$floor_refs" ] || \
    fail "只抽到 $refs_seen 個引用(下限 $floor_refs)——抽取本身可能壞了"

finish
